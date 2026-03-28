import { createApp } from './app';
import { config, validateConfig } from './config';
import { prisma } from './models/prisma';
import { AuthService } from './services/auth.service';
import { createLogger } from './utils/logger';

const logger = createLogger('Server');

/**
 * Start the server
 */
async function startServer(): Promise<void> {
  try {
    // Validate configuration
    validateConfig();
    logger.info('Configuration validated');

    // Connect to database
    await prisma.$connect();
    logger.info('Database connected');

    // Initialize default users
    const authService = new AuthService();
    await authService.initializeDefaultUsers();

    // Create Express app
    const app = createApp();

    // Start listening (bind to all interfaces to allow iPhone connection)
    const server = app.listen(config.port, '0.0.0.0', () => {
      logger.info(`Server listening on http://0.0.0.0:${config.port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
    });

    // Graceful shutdown
    const shutdown = async () => {
      logger.info('Shutting down server...');

      server.close(() => {
        logger.info('HTTP server closed');
      });

      await prisma.$disconnect();
      logger.info('Database disconnected');

      process.exit(0);
    };

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);

  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
}

// Start the server
startServer();
