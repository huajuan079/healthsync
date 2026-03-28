import express, { type Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';
import { createLogger } from './utils/logger';
import routes from './routes';

const logger = createLogger('App');

/**
 * Create and configure Express application
 */
export function createApp(): Application {
  const app = express();

  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: false, // Disable for API
    crossOriginEmbedderPolicy: false,
  }));

  // CORS
  app.use(cors({
    origin: config.cors.origin,
    credentials: true,
  }));

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Rate limiting
  const limiter = rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      res.status(429).json({
        error: 'Too many requests',
        retryAfter: Math.ceil(config.rateLimit.windowMs / 1000),
      });
    },
  });
  app.use('/api', limiter);

  // Request logging
  app.use((req, res, next) => {
    logger.debug(`${req.method} ${req.path}`);
    next();
  });

  // API routes
  app.use('/api', routes);

  // 404 handler
  app.use(notFoundHandler);

  // Error handler
  app.use(errorHandler);

  return app;
}
