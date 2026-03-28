import { z } from 'zod';
import { prisma } from '../models/prisma';
import { StorageService } from './storage.service';
import { verifyChecksum } from '../config/encryption';
import type { HealthDataBatch, SyncStatusResponse } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('HealthService');

// Validation schemas
const uploadSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  batch_index: z.number().int().min(0),
  batch_total: z.number().int().min(1),
  data: z.string().min(1),
  checksum: z.string().length(64),
});

export class HealthService {
  private storage: StorageService;

  constructor() {
    this.storage = new StorageService();
  }

  /**
   * Upload encrypted health data batch
   */
  async uploadBatch(
    username: string,
    userId: string,
    batch: HealthDataBatch
  ): Promise<{ batchId: string; message: string }> {
    // Validate input
    const validated = uploadSchema.parse(batch);

    // Verify checksum
    const expectedChecksum = verifyChecksum(validated.data, validated.checksum);
    if (!expectedChecksum) {
      throw new Error('Checksum verification failed');
    }

    // Check if batch already exists
    const existing = await prisma.upload.findUnique({
      where: {
        userId_date_batchIndex: {
          userId,
          date: validated.date,
          batchIndex: validated.batch_index,
        },
      },
    });

    if (existing) {
      // Update existing batch
      await prisma.upload.update({
        where: { id: existing.id },
        data: {
          recordCount: this.estimateRecordCount(validated.data),
          checksum: validated.checksum,
          fileSize: validated.data.length,
          status: 'completed',
          errorMessage: null,
        },
      });

      // Store the encrypted data
      await this.storage.storeBatch(
        username,
        validated.date,
        validated.batch_index,
        validated.data,
        validated.checksum
      );

      logger.info(`Updated batch ${validated.batch_index} for ${username} on ${validated.date}`);

      return { batchId: existing.id, message: 'Batch updated successfully' };
    }

    // Create new upload record
    const upload = await prisma.upload.create({
      data: {
        userId,
        date: validated.date,
        batchIndex: validated.batch_index,
        batchTotal: validated.batch_total,
        recordCount: this.estimateRecordCount(validated.data),
        checksum: validated.checksum,
        fileSize: validated.data.length,
        status: 'completed',
      },
    });

    // Store the encrypted data
    await this.storage.storeBatch(
      username,
      validated.date,
      validated.batch_index,
      validated.data,
      validated.checksum
    );

    // Update sync status
    await this.updateSyncStatus(userId, validated.date);

    logger.info(`Uploaded batch ${validated.batch_index}/${validated.batch_total} for ${username} on ${validated.date}`);

    return { batchId: upload.id, message: 'Batch uploaded successfully' };
  }

  /**
   * Get sync status for a user
   */
  async getSyncStatus(userId: string, username: string): Promise<SyncStatusResponse> {
    let syncStatus = await prisma.syncStatus.findUnique({
      where: { userId },
    });

    if (!syncStatus) {
      // Create initial sync status
      syncStatus = await prisma.syncStatus.create({
        data: {
          userId,
          totalRecords: 0,
          totalUploads: 0,
          dataTypes: '[]',
        },
      });
    }

    // Get available dates from storage
    const availableDates = await this.storage.getAvailableDates(username);

    return {
      last_sync_at: syncStatus.lastSyncAt?.toISOString() || null,
      last_fetch_at: syncStatus.lastFetchAt?.toISOString() || null,
      total_records: syncStatus.totalRecords,
      total_uploads: availableDates.length,
      data_types: JSON.parse(syncStatus.dataTypes),
    };
  }

  /**
   * Fetch data for Mac Mini (returns encrypted batches)
   */
  async fetchData(
    username: string,
    startDate?: string,
    endDate?: string
  ): Promise<Array<{ date: string; batches: Array<{ index: number; data: string; checksum: string }> }>> {
    let dates = await this.storage.getAvailableDates(username);

    // Filter by date range if provided
    if (startDate) {
      dates = dates.filter(d => d >= startDate);
    }
    if (endDate) {
      dates = dates.filter(d => d <= endDate);
    }

    const result = [];

    for (const date of dates) {
      const batches = await this.storage.getBatches(username, date);
      result.push({
        date,
        batches: batches.sort((a, b) => a.index - b.index),
      });
    }

    // Update last fetch time
    const user = await prisma.user.findUnique({
      where: { username },
    });

    if (user) {
      await prisma.syncStatus.update({
        where: { userId: user.id },
        data: { lastFetchAt: new Date() },
      });
    }

    logger.info(`Fetched ${dates.length} days of data for ${username}`);

    return result;
  }

  /**
   * Delete data after fetching (for archival)
   */
  async deleteAfterFetch(username: string, dates: string[]): Promise<void> {
    for (const date of dates) {
      await this.storage.deleteDate(username, date);

      // Also delete upload records
      const user = await prisma.user.findUnique({
        where: { username },
      });

      if (user) {
        await prisma.upload.deleteMany({
          where: {
            userId: user.id,
            date,
          },
        });
      }
    }

    logger.info(`Deleted ${dates.length} days of data after fetch for ${username}`);
  }

  /**
   * Estimate record count from encrypted data size (rough estimate)
   */
  private estimateRecordCount(data: string): number {
    // Base64 encoded JSON is approximately 33% larger than original
    // Each record is roughly 200-500 bytes when JSON encoded
    const estimatedSize = data.length * 0.75;
    return Math.max(1, Math.floor(estimatedSize / 300));
  }

  /**
   * Update sync status after upload
   */
  private async updateSyncStatus(userId: string, date: string): Promise<void> {
    const totalUploads = await prisma.upload.groupBy({
      by: ['date'],
      where: { userId },
    });

    const totalRecords = await prisma.upload.aggregate({
      where: { userId },
      _sum: { recordCount: true },
    });

    await prisma.syncStatus.upsert({
      where: { userId },
      create: {
        userId,
        lastSyncAt: new Date(),
        totalRecords: totalRecords._sum.recordCount || 0,
        totalUploads: totalUploads.length,
        dataTypes: JSON.stringify([
          'sleep',
          'heart_rate',
          'hrv',
          'steps',
          'workouts',
          'blood_oxygen',
          'menstrual',
          'weight',
          'medications',
          'mindfulness',
        ]),
      },
      update: {
        lastSyncAt: new Date(),
        totalRecords: totalRecords._sum.recordCount || 0,
        totalUploads: totalUploads.length,
      },
    });
  }

  /**
   * Get recent upload history
   */
  async getRecentUploads(userId: string, limit: number = 10) {
    return prisma.upload.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }
}
