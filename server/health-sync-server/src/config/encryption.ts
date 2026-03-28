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
 * Decrypt iOS encrypted data (AES-256-GCM with format: iv:tag:ciphertext in base64)
 */
export function decryptIOSEncryptedData(encryptedBase64: string, username: string): string {
  try {
    const key = getEncryptionKey(username);

    // Split the encrypted data format: iv:tag:ciphertext
    const parts = encryptedBase64.split(':');
    if (parts.length !== 3) {
      throw new Error('Invalid encrypted data format. Expected iv:tag:ciphertext');
    }

    const [ivBase64, tagBase64, ciphertextBase64] = parts;

    // Decode base64
    const iv = Buffer.from(ivBase64, 'base64');
    const tag = Buffer.from(tagBase64, 'base64');
    const ciphertext = Buffer.from(ciphertextBase64, 'base64');

    // Create decipher
    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);

    // Set auth tag (tag in GCM mode)
    decipher.setAuthTag(tag);

    // Decrypt
    let decrypted = decipher.update(ciphertext, undefined, 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  } catch (error) {
    console.error('Decryption error:', error);
    throw new Error('Failed to decrypt data: ' + (error as Error).message);
  }
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
