import dotenv from 'dotenv';
import path from 'path';
import os from 'os';
import fs from 'fs';

dotenv.config();

export interface UserConfig {
  username: string;
  encryptionKey: string;
}

export const config = {
  server: {
    url: process.env.SERVER_URL || 'http://localhost:3000',
    adminUsername: process.env.ADMIN_USERNAME || 'admin',
    adminPassword: process.env.ADMIN_PASSWORD || 'admin123',
  },

  workspace: {
    path: process.env.WORKSPACE_PATH
      ? process.env.WORKSPACE_PATH.replace('~', os.homedir())
      : path.join(os.homedir(), '.openclaw', 'workspace', 'health'),
  },

  keys: {
    path: process.env.KEYS_PATH
      ? process.env.KEYS_PATH.replace('~', os.homedir())
      : path.join(os.homedir(), '.openclaw', 'keys'),
  },

  encryption: {
    zhugong: process.env.ENCRYPTION_KEY_ZHUGONG || '',
    dage: process.env.ENCRYPTION_KEY_DAGE || '',
  },

  users: ['zhugong', 'dage'] as const,
};

/**
 * Ensure workspace directories exist
 */
export function ensureWorkspace(): void {
  const dirs = [
    config.workspace.path,
    path.join(config.workspace.path, 'zhugong'),
    path.join(config.workspace.path, 'dage'),
    config.keys.path,
  ];

  for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }
}

/**
 * Get encryption key for a user
 */
export function getEncryptionKey(username: string): string {
  const key = config.encryption[username as keyof typeof config.encryption];
  if (!key) {
    throw new Error(`No encryption key found for user: ${username}`);
  }
  return key;
}

/**
 * Load keys from file if exists
 */
export function loadKeysFromFile(): void {
  const keyFilePath = path.join(config.keys.path, 'health_sync.json');

  if (fs.existsSync(keyFilePath)) {
    try {
      const content = fs.readFileSync(keyFilePath, 'utf-8');
      const keys = JSON.parse(content);

      if (keys.zhugong) config.encryption.zhugong = keys.zhugong;
      if (keys.dage) config.encryption.dage = keys.dage;

      console.log('Loaded encryption keys from file');
    } catch (error) {
      console.warn('Failed to load keys from file:', error);
    }
  }
}
