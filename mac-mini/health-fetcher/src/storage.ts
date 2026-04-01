import fs from 'fs/promises';
import path from 'path';
import { config } from './config';

export interface HealthData {
  date: string;
  user: string;
  sync_time: string;
  sleep: any[];
  heart_rate: any[];
  resting_heart_rate: any;
  hrv: any[];
  steps: any;
  workouts: any[];
  blood_oxygen: any[];
  menstrual: any[];
  weight: any;
  medications: any[];
  mindfulness: any[];

  // New health data types
  wrist_temperature?: any;
  respiratory_rate?: any;
  body_temperature?: any;
  blood_pressure?: any;
  active_energy_burned?: any;
  stand_hours?: any;
  flights_climbed?: any;
  exercise_time?: any;
}

/**
 * Save health data to local JSON file (already decrypted)
 */
export async function saveHealthData(
  username: string,
  date: string,
  data: HealthData
): Promise<void> {
  const userDir = path.join(config.workspace.path, username);
  await fs.mkdir(userDir, { recursive: true });

  const filePath = path.join(userDir, `${date}.json`);
  await fs.writeFile(filePath, JSON.stringify(data, null, 2), 'utf-8');
}

/**
 * Load health data from local file
 */
export async function loadHealthData(
  username: string,
  date: string
): Promise<HealthData | null> {
  const filePath = path.join(config.workspace.path, username, `${date}.json`);

  try {
    const content = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(content);
  } catch {
    return null;
  }
}

/**
 * Get all available dates for a user
 */
export async function getAvailableDates(username: string): Promise<string[]> {
  const userDir = path.join(config.workspace.path, username);

  try {
    const files = await fs.readdir(userDir);
    return files
      .filter((f) => f.endsWith('.json'))
      .map((f) => f.replace('.json', ''))
      .sort()
      .reverse();
  } catch {
    return [];
  }
}

/**
 * Get summary of stored data
 */
export async function getDataSummary(username: string): Promise<{
  totalDays: number;
  oldestDate?: string;
  newestDate?: string;
  totalSize: number;
}> {
  const dates = await getAvailableDates(username);
  const userDir = path.join(config.workspace.path, username);

  let totalSize = 0;

  for (const date of dates) {
    const filePath = path.join(userDir, `${date}.json`);
    try {
      const stats = await fs.stat(filePath);
      totalSize += stats.size;
    } catch {
      // File might not exist
    }
  }

  return {
    totalDays: dates.length,
    oldestDate: dates[dates.length - 1],
    newestDate: dates[0],
    totalSize,
  };
}
