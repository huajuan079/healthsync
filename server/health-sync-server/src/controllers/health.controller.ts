import { Request, Response, NextFunction } from 'express';
import { HealthService } from '../services/health.service';
import { createLogger } from '../utils/logger';

const logger = createLogger('HealthController');
const healthService = new HealthService();

export class HealthController {
  /**
   * POST /health/upload
   */
  async upload(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const username = req.user?.username;
      const userId = req.user?.userId;

      if (!username || !userId) {
        res.status(401).json({ error: 'Not authenticated' });
        return;
      }

      const result = await healthService.uploadBatch(username, userId, req.body);

      res.json({
        success: true,
        batch_id: result.batchId,
        message: result.message,
      });
    } catch (error) {
      logger.error('Upload error', { error });
      if (error instanceof Error) {
        res.status(400).json({ success: false, error: error.message });
      } else {
        next(error);
      }
    }
  }

  /**
   * GET /health/status
   */
  async status(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const username = req.user?.username;
      const userId = req.user?.userId;

      if (!username || !userId) {
        res.status(401).json({ error: 'Not authenticated' });
        return;
      }

      const status = await healthService.getSyncStatus(userId, username);

      res.json(status);
    } catch (error) {
      logger.error('Status error', { error });
      next(error);
    }
  }

  /**
   * GET /health/fetch - For Mac Mini to pull data
   */
  async fetch(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { username, startDate, endDate } = req.query;

      if (!username || typeof username !== 'string') {
        res.status(400).json({ error: 'Username is required' });
        return;
      }

      // Verify user exists
      const data = await healthService.fetchData(
        username,
        startDate as string,
        endDate as string
      );

      res.json({
        success: true,
        username,
        count: data.length,
        data,
      });
    } catch (error) {
      logger.error('Fetch error', { error });
      next(error);
    }
  }

  /**
   * DELETE /health/cleanup - Clean up old data
   */
  async cleanup(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      // Admin only endpoint
      if (req.user?.role !== 'admin') {
        res.status(403).json({ error: 'Admin access required' });
        return;
      }

      const { StorageService } = await import('../services/storage.service');
      const storage = new StorageService();

      await storage.cleanupAllUsersData();

      res.json({ success: true, message: 'Cleanup completed' });
    } catch (error) {
      logger.error('Cleanup error', { error });
      next(error);
    }
  }

  /**
   * GET /health/healthcheck - Health check endpoint
   */
  async healthcheck(req: Request, res: Response): Promise<void> {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  }
}

export const healthController = new HealthController();
