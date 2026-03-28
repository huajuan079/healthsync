import { PrismaClient } from '@prisma/client';
import { createLogger } from '../utils/logger';

const logger = createLogger('Prisma');

// Extend PrismaClient with logging
class PrismaClientExtended extends PrismaClient {
  constructor() {
    super({
      log: [
        { level: 'query', emit: 'event' },
        { level: 'error', emit: 'stdout' },
        { level: 'warn', emit: 'stdout' },
      ],
    });

    if (process.env.NODE_ENV === 'development') {
      this.$on('query' as any, (e: any) => {
        logger.debug(`Query: ${e.query}`);
        logger.debug(`Duration: ${e.duration}ms`);
      });
    }
  }
}

export const prisma = new PrismaClientExtended();
