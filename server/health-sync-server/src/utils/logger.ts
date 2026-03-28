type LogLevel = 'info' | 'warn' | 'error' | 'debug';

const colors = {
  info: '\x1b[36m', // cyan
  warn: '\x1b[33m', // yellow
  error: '\x1b[31m', // red
  debug: '\x1b[90m', // gray
  reset: '\x1b[0m',
};

export class Logger {
  private context: string;

  constructor(context: string) {
    this.context = context;
  }

  private log(level: LogLevel, message: string, meta?: any): void {
    const timestamp = new Date().toISOString();
    const color = colors[level];
    const reset = colors.reset;

    const metaStr = meta ? ` ${JSON.stringify(meta)}` : '';
    console.log(`${color}[${timestamp}] [${level.toUpperCase()}] [${this.context}]${reset} ${message}${metaStr}`);
  }

  info(message: string, meta?: any): void {
    this.log('info', message, meta);
  }

  warn(message: string, meta?: any): void {
    this.log('warn', message, meta);
  }

  error(message: string, meta?: any): void {
    this.log('error', message, meta);
  }

  debug(message: string, meta?: any): void {
    if (process.env.NODE_ENV === 'development') {
      this.log('debug', message, meta);
    }
  }
}

export function createLogger(context: string): Logger {
  return new Logger(context);
}
