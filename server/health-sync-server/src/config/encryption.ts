import crypto from 'crypto';
import { config } from './index';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const SALT_LENGTH = 64;
const TAG_LENGTH = 16;
const KEY_LENGTH = 32;

/**
 * Get encryption key for a specific user
 */
export function getEncryptionKey(username: string): Buffer {
  const key = config.encryption[username as keyof typeof config.encryption] as string | undefined;
  if (!key) {
    throw new Error(`No encryption key found for user: ${username}`);
  }
  return Buffer.from(key, 'hex');
}

/**
 * Encrypt data using AES-256-GCM
 */
export function encrypt(plaintext: string, username: string): {
  encrypted: string;
  iv: string;
  tag: string;
} {
  const key = getEncryptionKey(username);
  const iv = crypto.randomBytes(IV_LENGTH);

  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');

  const tag = cipher.getAuthTag();

  return {
    encrypted,
    iv: iv.toString('hex'),
    tag: tag.toString('hex'),
  };
}

/**
 * Decrypt data using AES-256-GCM
 */
export function decrypt(encrypted: string, iv: string, tag: string, username: string): string {
  const key = getEncryptionKey(username);

  const decipher = crypto.createDecipheriv(
    ALGORITHM,
    key,
    Buffer.from(iv, 'hex')
  );

  decipher.setAuthTag(Buffer.from(tag, 'hex'));

  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');

  return decrypted;
}

/**
 * Calculate SHA-256 checksum
 */
export function calculateChecksum(data: string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Verify checksum
 */
export function verifyChecksum(data: string, checksum: string): boolean {
  return calculateChecksum(data) === checksum;
}

/**
 * Derive key from password using PBKDF2
 */
export function deriveKey(password: string, salt?: string): {
  key: string;
  salt: string;
} {
  const saltBuffer = salt ? Buffer.from(salt, 'hex') : crypto.randomBytes(SALT_LENGTH);

  const key = crypto.pbkdf2Sync(
    password,
    saltBuffer,
    100000,
    KEY_LENGTH,
    'sha256'
  );

  return {
    key: key.toString('hex'),
    salt: saltBuffer.toString('hex'),
  };
}
