import { Router } from 'express';
import { healthController } from '../controllers/health.controller';
import { authenticate } from '../middleware/auth.middleware';
import { requireApiKey } from '../middleware/apikey.middleware';

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
 * Fetch encrypted health data (legacy, for compatibility)
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

// ===== Admin API for Mac Mini (authenticated by API Key) =====

/**
 * GET /health/admin/users
 * Get list of available users
 */
router.get('/admin/users', requireApiKey, healthController.adminGetUsers.bind(healthController));

/**
 * GET /health/admin/dates
 * Get available data dates for a user
 */
router.get('/admin/dates', requireApiKey, healthController.adminGetDates.bind(healthController));

/**
 * GET /health/admin/fetch-decrypted
 * Fetch and decrypt health data (returns plaintext)
 * For Mac Mini - authenticated by API Key
 */
router.get('/admin/fetch-decrypted', requireApiKey, healthController.adminFetchDecrypted.bind(healthController));

export { router as healthRoutes };
