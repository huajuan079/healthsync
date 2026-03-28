import { Router } from 'express';
import { healthController } from '../controllers/health.controller';
import { authenticate, requireAdmin } from '../middleware/auth.middleware';

const router = Router();

/**
 * GET /health/healthcheck
 * Public health check endpoint
 */
router.get('/healthcheck', healthController.healthcheck.bind(healthController));

/**
 * POST /health/upload
 * Upload encrypted health data batch
 */
router.post('/upload', authenticate, healthController.upload.bind(healthController));

/**
 * GET /health/status
 * Get sync status for current user
 */
router.get('/status', authenticate, healthController.status.bind(healthController));

/**
 * GET /health/fetch
 * Fetch encrypted data (for Mac Mini)
 * Uses API key or admin token for authentication
 */
router.get('/fetch', authenticate, requireAdmin, healthController.fetch.bind(healthController));

/**
 * DELETE /health/cleanup
 * Clean up old data (admin only)
 */
router.delete('/cleanup', authenticate, requireAdmin, healthController.cleanup.bind(healthController));

export { router as healthRoutes };
