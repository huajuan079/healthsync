import dotenv from 'dotenv';
import path from 'path';
import os from 'os';
import fs from 'fs';

dotenv.config();

export const config = {
  server: {
    url: process.env.SERVER_URL || 'http://localhost:3000',
    apiKey: process.env.API_KEY || '', // API Key for Mac Mini authentication
  },

  workspace: {
    path: process.env.WORKSPACE_PATH
      ? process.env.WORKSPACE_PATH.replace('~', os.homedir())
      : path.join(os.homedir(), '.openclaw', 'workspace', 'health'),
  },
};

/**
 * Ensure workspace directories exist
 */
export function ensureWorkspace(): void {
  const dirs = [
    config.workspace.path,
  ];

  for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  // Create user subdirectories as needed
  const users = ['zhugong', 'dage'];
  for (const user of users) {
    const userDir = path.join(config.workspace.path, user);
    if (!fs.existsSync(userDir)) {
      fs.mkdirSync(userDir, { recursive: true });
    }
  }
}
