import { Request, Response, NextFunction } from 'express';
import { createLogger } from '../utils/logger';

const logger = createLogger('ApiKeyAuth');

/**
 * Middleware to authenticate requests using API Key
 * For Mac Mini and other trusted services
 */
export function requireApiKey(req: Request, res: Response, next: NextFunction): void {
  const apiKey = req.headers['x-api-key'] as string;

  if (!apiKey) {
    res.status(401).json({ error: 'API Key is required' });
    return;
  }

  // Support both API_KEY and MAC_MINI_API_KEY for compatibility
  const validApiKey = process.env.API_KEY || process.env.MAC_MINI_API_KEY;

  if (!validApiKey) {
    logger.error('API Key not configured in environment');
    res.status(500).json({ error: 'Server configuration error' });
    return;
  }

  if (apiKey !== validApiKey) {
    logger.warn('Invalid API Key attempt');
    res.status(403).json({ error: 'Invalid API Key' });
    return;
  }

  // Mark request as authenticated by API key
  (req as any).isApiKeyAuth = true;
  next();
}
