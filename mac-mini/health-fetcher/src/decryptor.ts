import crypto from 'crypto';
import { getEncryptionKey } from './config';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const TAG_LENGTH = 16;

export interface EncryptedBatch {
  index: number;
  data: string;
  checksum: string;
}

/**
 * Decrypt data using AES-256-GCM
 */
export function decryptData(
  encryptedBase64: string,
  username: string
): string {
  const keyHex = getEncryptionKey(username);
  const key = Buffer.from(keyHex, 'hex');

  // Parse encrypted data (format: iv:tag:encrypted)
  const parts = encryptedBase64.split(':');
  if (parts.length !== 3) {
    throw new Error('Invalid encrypted data format');
  }

  const iv = Buffer.from(parts[0], 'hex');
  const tag = Buffer.from(parts[1], 'hex');
  const encrypted = Buffer.from(parts[2], 'hex');

  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(tag);

  let decrypted = decipher.update(encrypted);
  decrypted = Buffer.concat([decrypted, decipher.final()]);

  return decrypted.toString('utf-8');
}

/**
 * Decrypt multiple batches and merge them
 */
export function decryptAndMergeBatches(
  batches: EncryptedBatch[],
  username: string
): any {
  const allData: any = {
    sleep: [],
    heart_rate: [],
    hrv: [],
    steps: [],
    workouts: [],
    blood_oxygen: [],
    menstrual: [],
    weight: [],
    medications: [],
    mindfulness: [],
  };

  for (const batch of batches) {
    try {
      // Decrypt the batch data
      const decrypted = decryptData(batch.data, username);
      const data = JSON.parse(decrypted);

      // Merge each data type
      for (const key of Object.keys(allData)) {
        if (data[key] && Array.isArray(data[key])) {
          allData[key] = allData[key].concat(data[key]);
        }
      }
    } catch (error) {
      console.error(`Failed to decrypt batch ${batch.index}:`, error);
      throw error;
    }
  }

  return allData;
}

/**
 * Verify SHA-256 checksum
 */
export function verifyChecksum(data: string, checksum: string): boolean {
  const hash = crypto.createHash('sha256').update(data).digest('hex');
  return hash === checksum;
}
