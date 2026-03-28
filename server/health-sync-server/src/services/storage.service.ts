import fs from 'fs/promises';
import path from 'path';
import { config } from '../config';
import { prisma } from '../models/prisma';
import { createLogger } from '../utils/logger';

const logger = createLogger('StorageService');

/**
 * Service for managing encrypted health data file storage
 */
export class StorageService {
  private basePath: string;

  constructor() {
    this.basePath = config.storage.basePath;
  }

  /**
   * Get user storage path
   */
  getUserPath(username: string): string {
    return path.join(this.basePath, username);
  }

  /**
   * Get date file path for a user
   */
  getFilePath(username: string, date: string): string {
    return path.join(this.getUserPath(username), `${date}.json`);
  }

  /**
   * Ensure user directory exists
   */
  private async ensureUserDir(username: string): Promise<void> {
    const userPath = this.getUserPath(username);
    try {
      await fs.mkdir(userPath, { recursive: true });
    } catch (error) {
      logger.error(`Failed to create user directory: ${userPath}`, { error });
      throw error;
    }
  }

  /**
   * Store encrypted data batch
   */
  async storeBatch(
    username: string,
    date: string,
    batchIndex: number,
    encryptedData: string,
    checksum: string
  ): Promise<void> {
    await this.ensureUserDir(username);

    const filePath = this.getFilePath(username, date);

    // Read existing batches or create new
    let batches: Record<number, { data: string; checksum: string }> = {};

    try {
      const existing = await fs.readFile(filePath, 'utf-8');
      batches = JSON.parse(existing);
    } catch {
      // File doesn't exist yet, create new
    }

    // Store the batch
    batches[batchIndex] = {
      data: encryptedData,
      checksum,
    };

    // Write back
    await fs.writeFile(filePath, JSON.stringify(batches, null, 2));

    logger.debug(`Stored batch ${batchIndex} for ${username} on ${date}`);
  }

  /**
   * Retrieve all batches for a specific date
   */
  async getBatches(username: string, date: string): Promise<Array<{ index: number; data: string; checksum: string }>> {
    const filePath = this.getFilePath(username, date);

    try {
      const content = await fs.readFile(filePath, 'utf-8');
      const batches: Record<number, { data: string; checksum: string }> = JSON.parse(content);

      return Object.entries(batches).map(([index, batch]) => ({
        index: parseInt(index, 10),
        data: batch.data,
        checksum: batch.checksum,
      }));
    } catch {
      return [];
    }
  }

  /**
   * Get all available dates for a user
   */
  async getAvailableDates(username: string): Promise<string[]> {
    const userPath = this.getUserPath(username);

    try {
      const files = await fs.readdir(userPath);
      return files
        .filter(f => f.endsWith('.json'))
        .map(f => f.replace('.json', ''))
        .sort()
        .reverse();
    } catch {
      return [];
    }
  }

  /**
   * Delete data for a specific date
   */
  async deleteDate(username: string, date: string): Promise<void> {
    const filePath = this.getFilePath(username, date);

    try {
      await fs.unlink(filePath);
      logger.info(`Deleted data for ${username} on ${date}`);
    } catch {
      // File might not exist, ignore
    }
  }

  /**
   * Clean up old data based on retention policy
   */
  async cleanupOldData(username: string): Promise<number> {
    const dates = await this.getAvailableDates(username);
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - config.dataRetention.days);

    let deletedCount = 0;

    for (const date of dates) {
      const fileDate = new Date(date);
      if (fileDate < cutoffDate) {
        await this.deleteDate(username, date);
        deletedCount++;
      }
    }

    if (deletedCount > 0) {
      logger.info(`Cleaned up ${deletedCount} old data files for ${username}`);
    }

    return deletedCount;
  }

  /**
   * Clean up all users' old data
   */
  async cleanupAllUsersData(): Promise<void> {
    const users = await prisma.user.findMany({
      where: { isActive: true },
    });

    for (const user of users) {
      await this.cleanupOldData(user.username);
    }

    // Also clean up expired sessions
    await prisma.session.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    });

    logger.info('Completed cleanup of all users data');
  }

  /**
   * Delete all data for a user (for testing/reset)
   */
  async deleteAllUserData(username: string): Promise<void> {
    const userPath = this.getUserPath(username);

    try {
      const files = await fs.readdir(userPath);
      for (const file of files) {
        await fs.unlink(path.join(userPath, file));
      }
      logger.info(`Deleted all data for ${username}`);
    } catch {
      // Directory might not exist
    }
  }
}
