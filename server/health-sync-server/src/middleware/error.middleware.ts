import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { createLogger } from '../utils/logger';

const logger = createLogger('ErrorMiddleware');

export function errorHandler(
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  logger.error(`${req.method} ${req.path}`, {
    error: error.message,
    stack: error.stack,
  });

  // Handle Zod validation errors
  if (error instanceof ZodError) {
    res.status(400).json({
      error: 'Validation error',
      details: error.errors,
    });
    return;
  }

  // Handle custom API errors
  if ('statusCode' in error && typeof (error as any).statusCode === 'number') {
    const apiError = error as { statusCode: number; message: string; code?: string };
    res.status(apiError.statusCode).json({
      error: apiError.message,
      code: apiError.code,
    });
    return;
  }

  // Default error response
  res.status(500).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : error.message,
  });
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({ error: 'Not found', path: req.path });
}
