import { Router } from 'express';
import { healthController } from '../controllers/health.controller';
import { authenticate } from '../middleware/auth.middleware';

const router = Router();

/**
 * POST /health/upload
 * Upload encrypted health data (requires authentication)
 */
router.post('/upload', authenticate, healthController.upload.bind(healthController));

/**
 * GET /health/status
 * Get sync status for current user (requires authentication)
 */
router.get('/status', authenticate, healthController.status.bind(healthController));

/**
 * GET /health/fetch
 * Fetch health data (for Mac Mini - requires admin or special auth)
 */
router.get('/fetch', healthController.fetch.bind(healthController));

/**
 * DELETE /health/cleanup
 * Clean up old data (admin only)
 */
router.delete('/cleanup', authenticate, healthController.cleanup.bind(healthController));

/**
 * GET /health/healthcheck
 * Health check endpoint
 */
router.get('/healthcheck', healthController.healthcheck.bind(healthController));

/**
 * GET /health/web/uploads
 * Web interface to view upload records (HTML page)
 */
router.get('/web/uploads', healthController.viewUploads.bind(healthController));

/**
 * GET /health/web/upload/:id
 * Web interface to view single upload detail
 */
router.get('/web/upload/:id', healthController.viewUploadDetail.bind(healthController));

export { router as healthRoutes };
