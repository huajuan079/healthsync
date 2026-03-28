import { Router } from 'express';
import { authController } from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth.middleware';

const router = Router();

/**
 * POST /auth/login
 * Authenticate user and receive tokens
 */
router.post('/login', authController.login.bind(authController));

/**
 * POST /auth/refresh
 * Refresh access token using refresh token
 */
router.post('/refresh', authController.refresh.bind(authController));

/**
 * POST /auth/logout
 * Logout and invalidate refresh token
 */
router.post('/logout', authenticate, authController.logout.bind(authController));

/**
 * GET /auth/me
 * Get current user info
 */
router.get('/me', authenticate, authController.me.bind(authController));

export { router as authRoutes };
