import axios, { AxiosInstance } from 'axios';
import { config, ensureWorkspace, loadKeysFromFile } from './config';
import { decryptAndMergeBatches } from './decryptor';
import { saveHealthData, getAvailableDates, getDataSummary } from './storage';

class HealthFetcher {
  private client: AxiosInstance;
  private accessToken: string | null = null;

  constructor() {
    this.client = axios.create({
      baseURL: config.server.url,
      timeout: 30000,
    });

    // Add auth interceptor
    this.client.interceptors.request.use((config) => {
      if (this.accessToken) {
        config.headers.Authorization = `Bearer ${this.accessToken}`;
      }
      return config;
    });
  }

  /**
   * Login and get access token
   */
  async login(): Promise<void> {
    try {
      const response = await this.client.post('/api/auth/login', {
        username: config.server.adminUsername,
        password: config.server.adminPassword,
      });

      this.accessToken = response.data.accessToken;
      console.log('Logged in successfully');
    } catch (error) {
      console.error('Login failed:', error);
      throw error;
    }
  }

  /**
   * Fetch data for a user
   */
  async fetchUserData(
    username: string,
    startDate?: string,
    endDate?: string
  ): Promise<any[]> {
    if (!this.accessToken) {
      await this.login();
    }

    try {
      const params: any = { username };
      if (startDate) params.startDate = startDate;
      if (endDate) params.endDate = endDate;

      const response = await this.client.get('/api/health/fetch', { params });

      return response.data.data;
    } catch (error) {
      console.error(`Failed to fetch data for ${username}:`, error);
      throw error;
    }
  }

  /**
   * Process and store fetched data
   */
  async processAndStore(username: string, fetchedData: any[]): Promise<void> {
    for (const dayData of fetchedData) {
      const { date, batches } = dayData;

      // Check if we already have this date
      const existing = await getAvailableDates(username);
      if (existing.includes(date)) {
        console.log(`Skipping ${username} data for ${date} (already exists)`);
        continue;
      }

      try {
        // Decrypt and merge batches
        const decrypted = decryptAndMergeBatches(batches, username);

        // Create health data object
        const healthData = {
          date,
          user: username,
          sync_time: new Date().toISOString(),
          ...decrypted,
        };

        // Save to local storage
        await saveHealthData(username, date, healthData);
        console.log(`✓ Stored ${username} data for ${date} (${batches.length} batches)`);
      } catch (error) {
        console.error(`✗ Failed to process ${username} data for ${date}:`, error);
      }
    }
  }

  /**
   * Fetch all data for all users
   */
  async fetchAll(): Promise<void> {
    ensureWorkspace();
    loadKeysFromFile();

    await this.login();

    for (const username of config.users) {
      console.log(`\nFetching data for ${username}...`);

      try {
        const data = await this.fetchUserData(username);
        console.log(`Fetched ${data.length} days of data`);

        await this.processAndStore(username, data);

        // Show summary
        const summary = await getDataSummary(username);
        console.log(`Summary for ${username}:`);
        console.log(`  Total days: ${summary.totalDays}`);
        console.log(`  Date range: ${summary.oldestDate || 'N/A'} to ${summary.newestDate || 'N/A'}`);
        console.log(`  Total size: ${(summary.totalSize / 1024).toFixed(2)} KB`);
      } catch (error) {
        console.error(`Failed to fetch data for ${username}:`, error);
      }
    }
  }

  /**
   * Fetch today's data only
   */
  async fetchToday(): Promise<void> {
    const today = new Date().toISOString().split('T')[0];

    ensureWorkspace();
    loadKeysFromFile();
    await this.login();

    for (const username of config.users) {
      console.log(`\nFetching today's data for ${username}...`);

      try {
        const data = await this.fetchUserData(username, today, today);
        await this.processAndStore(username, data);
      } catch (error) {
        console.error(`Failed to fetch today's data for ${username}:`, error);
      }
    }
  }
}

/**
 * Main entry point
 */
async function main(): Promise<void> {
  const mode = process.argv[2] || 'all';

  const fetcher = new HealthFetcher();

  switch (mode) {
    case 'today':
      console.log('Fetching today\'s data...');
      await fetcher.fetchToday();
      break;
    case 'all':
      console.log('Fetching all available data...');
      await fetcher.fetchAll();
      break;
    default:
      console.log(`Unknown mode: ${mode}`);
      console.log('Usage: npm start [today|all]');
      process.exit(1);
  }

  console.log('\nDone!');
}

main().catch(console.error);
