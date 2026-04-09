import { Request, Response, NextFunction } from 'express';
import { createHmac, timingSafeEqual } from 'crypto';
import path from 'path';
import { prisma } from '../models/prisma';
import { createLogger } from '../utils/logger';
import { StorageService } from '../services/storage.service.js';

const logger = createLogger('AdminWebController');

const COOKIE_NAME = 'admin_session';
const COOKIE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days in ms

function signToken(timestamp: number, secret: string): string {
  const hmac = createHmac('sha256', secret).update(String(timestamp)).digest('hex');
  return Buffer.from(`${timestamp}.${hmac}`).toString('base64');
}

function verifyToken(token: string, secret: string): boolean {
  try {
    const decoded = Buffer.from(token, 'base64').toString('utf8');
    const dotIdx = decoded.indexOf('.');
    if (dotIdx < 0) return false;
    const tsStr = decoded.slice(0, dotIdx);
    const hmac = decoded.slice(dotIdx + 1);
    const timestamp = parseInt(tsStr, 10);
    if (isNaN(timestamp) || Date.now() - timestamp > COOKIE_MAX_AGE_MS) return false;
    const expectedBuf = createHmac('sha256', secret).update(tsStr).digest();
    let hmacBuf: Buffer;
    try {
      hmacBuf = Buffer.from(hmac, 'hex');
    } catch {
      return false;
    }
    if (hmacBuf.length !== expectedBuf.length) return false;
    return timingSafeEqual(hmacBuf, expectedBuf);
  } catch {
    return false;
  }
}

function parseCookies(cookieHeader: string | undefined): Record<string, string> {
  if (!cookieHeader) return {};
  return cookieHeader.split(';').reduce((acc, c) => {
    const idx = c.indexOf('=');
    if (idx > 0) acc[c.slice(0, idx).trim()] = decodeURIComponent(c.slice(idx + 1).trim());
    return acc;
  }, {} as Record<string, string>);
}

export function requireAdminSession(req: Request, res: Response, next: NextFunction): void {
  const cookies = parseCookies(req.headers.cookie);
  const token = cookies[COOKIE_NAME];
  const secret = process.env.ADMIN_WEB_PASSWORD || '';
  if (!secret || !token || !verifyToken(token, secret)) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  next();
}

export class AdminWebController {
  serveAdmin(req: Request, res: Response): void {
    res.sendFile(path.join(__dirname, '../../public/admin/index.html'));
  }

  async login(req: Request, res: Response): Promise<void> {
    const { password } = req.body as { password?: string };
    const adminPassword = process.env.ADMIN_WEB_PASSWORD;
    if (!adminPassword) {
      res.status(500).json({ error: 'ADMIN_WEB_PASSWORD not configured' });
      return;
    }
    if (!password) {
      res.status(401).json({ error: '密码错误' });
      return;
    }
    const expected = createHmac('sha256', COOKIE_NAME).update(adminPassword).digest();
    const actual = createHmac('sha256', COOKIE_NAME).update(password).digest();
    if (!timingSafeEqual(actual, expected)) {
      res.status(401).json({ error: '密码错误' });
      return;
    }
    const token = signToken(Date.now(), adminPassword);
    res.cookie(COOKIE_NAME, token, {
      httpOnly: true,
      sameSite: 'strict',
      secure: process.env.NODE_ENV === 'production',
      maxAge: COOKIE_MAX_AGE_MS,
      path: '/',
    });
    res.json({ success: true });
  }

  logout(req: Request, res: Response): void {
    res.clearCookie(COOKIE_NAME, { path: '/' });
    res.json({ success: true });
  }

  async getUsers(req: Request, res: Response): Promise<void> {
    try {
      const users = await prisma.user.findMany({
        include: {
          syncStatus: true,
          _count: { select: { uploads: true } },
        },
        orderBy: { createdAt: 'asc' },
      });

      res.json({
        users: users.map(u => ({
          id: u.id,
          username: u.username,
          isActive: u.isActive,
          totalUploads: u._count.uploads,
          lastSyncAt: u.syncStatus[0]?.lastSyncAt ?? null,
        })),
      });
    } catch (error) {
      logger.error('Admin getUsers error', { error });
      res.status(500).json({ error: 'Internal server error' });
    }
  }

  async getUserUploads(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const page = Math.max(1, parseInt(req.query.page as string) || 1);
      const pageSize = 20;
      const allowedSortFields = ['date', 'recordCount', 'fileSize', 'createdAt'];
      const sortBy = allowedSortFields.includes(req.query.sortBy as string)
        ? (req.query.sortBy as string)
        : 'createdAt';
      const sortOrder: 'asc' | 'desc' = req.query.sortOrder === 'asc' ? 'asc' : 'desc';

      const user = await prisma.user.findUnique({ where: { id } });
      if (!user) {
        res.status(404).json({ error: 'User not found' });
        return;
      }

      const [total, data] = await Promise.all([
        prisma.upload.count({ where: { userId: id } }),
        prisma.upload.findMany({
          where: { userId: id },
          orderBy: { [sortBy]: sortOrder },
          skip: (page - 1) * pageSize,
          take: pageSize,
        }),
      ]);

      res.json({ total, page, pageSize, username: user.username, data });
    } catch (error) {
      logger.error('Admin getUserUploads error', { error });
      res.status(500).json({ error: 'Internal server error' });
    }
  }

  async getUploadDetail(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const upload = await prisma.upload.findUnique({
        where: { id },
        include: { user: true },
      }) as (Awaited<ReturnType<typeof prisma.upload.findUnique>> & { user: { username: string } }) | null;

      if (!upload) {
        res.status(404).json({ error: 'Upload not found' });
        return;
      }

      let fileContent: string | null = null;
      try {
        const storage = new StorageService();
        fileContent = await storage.readPlaintextData(upload.user.username, upload.date);
      } catch {
        // file archived or not found — leave null
      }

      res.json({
        id: upload.id,
        userId: upload.userId,
        username: upload.user.username,
        date: upload.date,
        batchIndex: upload.batchIndex,
        batchTotal: upload.batchTotal,
        recordCount: upload.recordCount,
        fileSize: upload.fileSize,
        status: upload.status,
        checksum: upload.checksum,
        errorMessage: upload.errorMessage ?? null,
        createdAt: upload.createdAt,
        updatedAt: (upload as any).updatedAt ?? null,
        fileContent,
      });
    } catch (error) {
      logger.error('Admin getUploadDetail error', { error });
      res.status(500).json({ error: 'Internal server error' });
    }
  }
}

export const adminWebController = new AdminWebController();
