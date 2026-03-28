import { Router } from 'express';
import { authRoutes } from './auth.routes';
import { healthRoutes } from './health.routes';

const router = Router();

// Mount routes
router.use('/auth', authRoutes);
router.use('/health', healthRoutes);

// Health check
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

export default router;
