import dotenv from 'dotenv';

// 本地开发优先加载 .env.development.local，回退到 .env
// dotenv.config 不会覆盖已经加载的值，所以顺序很重要
if (process.env.NODE_ENV === 'development') {
  dotenv.config({ path: '.env.development.local' });
}
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  jwt: {
    secret: process.env.JWT_SECRET || 'your-secret-key',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'your-refresh-secret',
    expiresIn: process.env.JWT_EXPIRES_IN || '1h',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  },

  dataRetention: {
    days: parseInt(process.env.DATA_RETENTION_DAYS || '90', 10), // 改为 90 天
  },

  cors: {
    origin: process.env.CORS_ORIGIN || '*',
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),
  },

  storage: {
    basePath: './storage/health_data',
  },

  apple: {
    clientId: process.env.APPLE_CLIENT_ID || '',
  },
} as const;

// Validate required config
export function validateConfig(): void {
  const required = ['jwt.secret', 'jwt.refreshSecret'];

  for (const key of required) {
    const value = key.split('.').reduce((obj, k) => obj?.[k], config as any);
    if (!value || value.includes('change-this')) {
      throw new Error(`Missing or invalid config: ${key}`);
    }
  }
}
