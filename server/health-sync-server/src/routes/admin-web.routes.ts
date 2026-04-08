import { Router } from 'express';
import { adminWebController, requireAdminSession } from '../controllers/admin-web.controller';

const router = Router();

// Serve SPA shell at /health/web/admin
router.get('/admin', (req, res) => adminWebController.serveAdmin(req, res));

// Auth endpoints (no session required)
router.post('/api/login', (req, res) => adminWebController.login(req, res));
router.post('/api/logout', (req, res) => adminWebController.logout(req, res));

// Protected JSON API
router.get('/api/users', requireAdminSession, (req, res) => adminWebController.getUsers(req, res));
router.get('/api/users/:id/uploads', requireAdminSession, (req, res) => adminWebController.getUserUploads(req, res));
router.get('/api/uploads/:id', requireAdminSession, (req, res) => adminWebController.getUploadDetail(req, res));

export { router as adminWebRoutes };
