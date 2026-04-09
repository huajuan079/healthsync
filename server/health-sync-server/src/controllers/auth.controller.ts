import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { AuthService } from '../services/auth.service';
import type { AppleLoginRequest } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('AuthController');
const authService = new AuthService();

// Validation schemas
const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refresh_token: z.string().min(1),
});

const appleLoginSchema = z.object({
  identityToken: z.string().min(1),
  userIdentifier: z.string().min(1),
  email: z.string().email().optional(),
  fullName: z.string().optional(),
});

export class AuthController {
  /**
   * POST /auth/login
   */
  async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { username, password } = loginSchema.parse(req.body);

      const result = await authService.login({ username, password });

      res.json(result);
    } catch (error) {
      if (error instanceof Error) {
        res.status(401).json({ error: error.message });
      } else {
        next(error);
      }
    }
  }

  /**
   * POST /auth/refresh
   */
  async refresh(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { refresh_token } = refreshSchema.parse(req.body);

      const result = await authService.refreshToken({ refreshToken: refresh_token });

      res.json(result);
    } catch (error) {
      if (error instanceof Error) {
        res.status(401).json({ error: error.message });
      } else {
        next(error);
      }
    }
  }

  /**
   * POST /auth/logout
   */
  async logout(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { refreshToken } = req.body;

      if (refreshToken) {
        await authService.logout(refreshToken);
      }

      res.json({ message: 'Logged out successfully' });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /auth/me - get current user info
   */
  async me(req: Request, res: Response): Promise<void> {
    if (req.user) {
      res.json({
        id: req.user.userId,
        username: req.user.username,
        role: req.user.role,
      });
    } else {
      res.status(401).json({ error: 'Not authenticated' });
    }
  }

  /**
   * POST /auth/apple
   */
  async appleLogin(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const body = appleLoginSchema.parse(req.body) as AppleLoginRequest;
      const result = await authService.appleLogin(body);
      res.json(result);
    } catch (error) {
      if (error instanceof Error) {
        res.status(401).json({ error: error.message });
      } else {
        next(error);
      }
    }
  }
}

export const authController = new AuthController();
