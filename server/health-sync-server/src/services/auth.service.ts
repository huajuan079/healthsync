import bcrypt from 'bcrypt';
import { prisma } from '../models/prisma';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../middleware/auth.middleware';
import type { LoginRequest, LoginResponse, RefreshTokenRequest } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('AuthService');

const SALT_ROUNDS = 12;

export class AuthService {
  /**
   * Authenticate user with username/password
   */
  async login(credentials: LoginRequest): Promise<LoginResponse> {
    const { username, password } = credentials;

    const user = await prisma.user.findUnique({
      where: { username },
    });

    if (!user) {
      logger.warn(`Login attempt for non-existent user: ${username}`);
      throw new Error('Invalid credentials');
    }

    if (!user.isActive) {
      throw new Error('Account is disabled');
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      logger.warn(`Invalid password for user: ${username}`);
      throw new Error('Invalid credentials');
    }

    // Generate tokens
    const tokenPayload = {
      userId: user.id,
      username: user.username,
      role: user.role,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);

    // Store refresh token in database
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await prisma.session.create({
      data: {
        userId: user.id,
        refreshToken,
        expiresAt,
      },
    });

    logger.info(`User logged in: ${username}`);

    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: 3600, // 1 hour
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
      },
    };
  }

  /**
   * Refresh access token using refresh token
   */
  async refreshToken(request: RefreshTokenRequest): Promise<{ access_token: string; expires_in: number }> {
    const { refreshToken } = request;

    // Verify the refresh token
    const payload = verifyRefreshToken(refreshToken);
    if (!payload) {
      throw new Error('Invalid refresh token');
    }

    // Check session exists and is not expired
    const session = await prisma.session.findUnique({
      where: { refreshToken },
    });

    if (!session || session.expiresAt < new Date()) {
      throw new Error('Expired refresh token');
    }

    // Generate new access token
    const accessToken = generateAccessToken({
      userId: payload.userId,
      username: payload.username,
      role: payload.role,
    });

    return {
      access_token: accessToken,
      expires_in: 3600, // 1 hour
    };
  }

  /**
   * Logout - delete refresh token
   */
  async logout(refreshToken: string): Promise<void> {
    await prisma.session.deleteMany({
      where: { refreshToken },
    });
  }

  /**
   * Clean up expired sessions
   */
  async cleanupExpiredSessions(): Promise<number> {
    const result = await prisma.session.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    });
    return result.count;
  }

  /**
   * Initialize default users (for development)
   */
  async initializeDefaultUsers(): Promise<void> {
    const defaults = [
      { username: 'zhugong', password: 'zhugong123' },
      { username: 'dage', password: 'dage123' },
    ];

    for (const def of defaults) {
      const existing = await prisma.user.findUnique({
        where: { username: def.username },
      });

      if (!existing) {
        const hashedPassword = await bcrypt.hash(def.password, SALT_ROUNDS);
        await prisma.user.create({
          data: {
            username: def.username,
            password: hashedPassword,
            role: 'user',
          },
        });
        logger.info(`Created default user: ${def.username} (password: ${def.password})`);
      }
    }
  }
}
