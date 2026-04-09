// Authentication Types
export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  user: UserInfo;
}

export interface RefreshTokenRequest {
  refreshToken: string;  // Internal use
}

export interface RefreshTokenResponse {
  access_token: string;
  expires_in: number;
}

export interface TokenPayload {
  userId: string;
  username: string;
  role: string;
}

export interface UserInfo {
  id: string;
  username: string;
  role: string;
}

// Health Data Types
export interface HealthDataBatch {
  date: string;
  batch_index: number;
  batch_total: number;
  data: string; // plaintext JSON data
  checksum: string;
}

export interface SyncStatusResponse {
  last_sync_at: string | null;
  last_fetch_at: string | null;
  total_records: number;
  total_uploads: number;
  data_types: string[];
}

export interface UploadResponse {
  success: boolean;
  batch_id: string;
  message: string;
}

export interface FetchDataRequest {
  username: string;
  startDate?: string;
  endDate?: string;
}

// Health Data Response Types (for Mac Mini)
export interface HealthData {
  date: string;
  user: string;
  sync_time: string;
  sleep: SleepRecord[];
  heart_rate: HeartRateRecord[];
  hrv: HRVRecord[];
  steps: StepRecord[];
  workouts: WorkoutRecord[];
  blood_oxygen: BloodOxygenRecord[];
  menstrual: MenstrualRecord[];
  weight: WeightRecord[];
  medications: MedicationRecord[];
  mindfulness: MindfulnessRecord[];
}

export interface SleepRecord {
  startDate: string;
  endDate: string;
  duration: number;
  type: string;
  source?: string;
}

export interface HeartRateRecord {
  timestamp: string;
  value: number;
  unit: string;
}

export interface HRVRecord {
  timestamp: string;
  value: number;
  unit: string;
}

export interface StepRecord {
  date: string;
  value: number;
  unit: string;
  distance?: number;
  distanceUnit?: string;
}

export interface WorkoutRecord {
  startDate: string;
  endDate: string;
  duration: number;
  type: string;
  distance?: number;
  energy?: number;
  source?: string;
}

export interface BloodOxygenRecord {
  timestamp: string;
  value: number;
  unit: string;
}

export interface MenstrualRecord {
  startDate: string;
  endDate?: string;
  type: string;
}

export interface WeightRecord {
  timestamp: string;
  value: number;
  unit: string;
  bmi?: number;
}

export interface MedicationRecord {
  date: string;
  name: string;
  dosage?: string;
}

export interface MindfulnessRecord {
  startDate: string;
  endDate: string;
  duration: number;
  type: string;
}

// Error Types
export interface ApiError {
  statusCode: number;
  message: string;
  code?: string;
}

// Express Request Extension
import { Request } from 'express';

declare global {
  namespace Express {
    interface Request {
      user?: TokenPayload;
    }
  }
}

export interface AppleLoginRequest {
  identityToken: string;
  userIdentifier: string;
  email?: string;
  fullName?: string;
}
