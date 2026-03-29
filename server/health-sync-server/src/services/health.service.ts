import { z } from 'zod';
import { prisma } from '../models/prisma';
import { StorageService } from './storage.service';
import type { SyncStatusResponse } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('HealthService');

// Validation schema for plaintext upload
const uploadSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  data: z.string().min(1), // Plaintext JSON
});

export class HealthService {
  private storage: StorageService;

  constructor() {
    this.storage = new StorageService();
  }

  /**
   * Upload plaintext health data
   * Data is stored as-is without encryption
   */
  async uploadBatch(
    username: string,
    userId: string,
    payload: any
  ): Promise<{ batchId: string; message: string }> {
    // Validate input
    const validated = uploadSchema.parse(payload);

    // Parse the JSON data to estimate record count
    let recordCount = 1;
    try {
      const jsonData = JSON.parse(validated.data);
      // Count all arrays and single values
      recordCount = Object.values(jsonData).filter((v: any) => {
        if (Array.isArray(v)) return v.length > 0;
        return v !== null && v !== undefined;
      }).length;
    } catch {
      // If JSON parse fails, use size estimate
      recordCount = Math.max(1, Math.floor(validated.data.length / 500));
    }

    // Check if we already have data for this date
    const existing = await prisma.upload.findFirst({
      where: {
        userId,
        date: validated.date,
      },
    });

    if (existing) {
      // Update existing record
      await prisma.upload.update({
        where: { id: existing.id },
        data: {
          recordCount,
          fileSize: validated.data.length,
          status: 'completed',
          errorMessage: null,
        },
      });

      // Store the plaintext data
      await this.storage.storePlaintextData(
        username,
        validated.date,
        validated.data
      );

      logger.info(`Updated health data for ${username} on ${validated.date}`);
      return { batchId: existing.id, message: 'Data updated successfully' };
    }

    // Create new upload record
    const upload = await prisma.upload.create({
      data: {
        userId,
        date: validated.date,
        batchIndex: 0,
        batchTotal: 1,
        recordCount,
        checksum: '', // No checksum for plaintext
        fileSize: validated.data.length,
        status: 'completed',
      },
    });

    // Store the plaintext data
    await this.storage.storePlaintextData(
      username,
      validated.date,
      validated.data
    );

    // Update sync status
    await this.updateSyncStatus(userId, validated.date);

    logger.info(`Uploaded health data for ${username} on ${validated.date}`);

    return { batchId: upload.id, message: 'Data uploaded successfully' };
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
   * Fetch data for Mac Mini (returns plaintext)
   */
  async fetchData(
    username: string,
    startDate?: string,
    endDate?: string
  ): Promise<Array<{ date: string; data: string }>> {
    let dates = await this.storage.getAvailableDates(username);

    // Filter by date range if provided
    if (startDate) {
      dates = dates.filter((d) => d >= startDate);
    }
    if (endDate) {
      dates = dates.filter((d) => d <= endDate);
    }

    const result = [];

    for (const date of dates) {
      const data = await this.storage.readPlaintextData(username, date);
      result.push({ date, data });
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
   * Estimate record count from data size
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
