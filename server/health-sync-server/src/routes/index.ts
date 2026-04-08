import { Router } from 'express';
import { authRoutes } from './auth.routes';
import { healthRoutes } from './health.routes';
import { adminWebRoutes } from './admin-web.routes';

const router = Router();

// Mount routes
router.use('/auth', authRoutes);
// Admin web must be mounted before /health to intercept /health/web/* first
router.use('/health/web', adminWebRoutes);
router.use('/health', healthRoutes);

// Health check
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

export default router;
