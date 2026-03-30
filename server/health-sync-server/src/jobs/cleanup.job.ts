import cron from 'node-cron';
import { logger } from '../utils/logger.js';
import { StorageService } from '../services/storage.service.js';
import { config } from '../config/index.js';

/**
 * Smart Cleanup Job - Runs daily at 3 AM to clean old data
 * Only deletes data older than retention period (default 90 days)
 */
export class CleanupJob {
  private task: cron.ScheduledTask | null = null;
  private storage: StorageService;

  constructor() {
    this.storage = new StorageService();
  }

  /**
   * Start the cleanup job
   * Runs every day at 3:00 AM (after Mac Mini fetch at 23:30)
   */
  start(): void {
    // Cron expression: 0 3 * * * (runs at 3:00 AM daily)
    this.task = cron.schedule('0 3 * * *', async () => {
      logger.info('Starting smart cleanup job...');
      logger.info(`Retention policy: ${config.dataRetention.days} days`);

      try {
        const deletedCount = await this.storage.cleanupAllUsersData();
        logger.info(`Smart cleanup job completed: deleted ${deletedCount} records`);
      } catch (error) {
        logger.error('Smart cleanup job failed:', error);
      }
    });

    logger.info(`Smart cleanup job scheduled to run daily at 3:00 AM (retention: ${config.dataRetention.days} days)`);
  }

  /**
   * Stop the cleanup job
   */
  stop(): void {
    if (this.task) {
      this.task.stop();
      this.task = null;
      logger.info('Cleanup job stopped');
    }
  }

  /**
   * Run cleanup job manually (for testing)
   */
  async runManual(): Promise<void> {
    logger.info('Running manual cleanup...');
    const deletedCount = await this.storage.cleanupAllUsersData();
    logger.info(`Manual cleanup completed: deleted ${deletedCount} records`);
    return deletedCount;
  }
}

// Export singleton instance
export const cleanupJob = new CleanupJob();
