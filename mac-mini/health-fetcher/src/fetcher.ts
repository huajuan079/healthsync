import axios, { AxiosInstance } from 'axios';
import { config, ensureWorkspace } from './config';
import { saveHealthData, getAvailableDates, getDataSummary } from './storage';

/**
 * Simplified HealthFetcher for Mac Mini
 * - Uses API Key for authentication (no user login needed)
 * - Server returns decrypted plaintext data
 * - No encryption keys needed on Mac Mini
 */
class HealthFetcher {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: config.server.url,
      timeout: 30000,
    });

    // Add API Key header
    this.client.interceptors.request.use((axiosConfig) => {
      axiosConfig.headers['X-API-Key'] = config.server.apiKey;
      return axiosConfig;
    });
  }

  /**
   * Get list of available users
   */
  async getUsers(): Promise<string[]> {
    try {
      const response = await this.client.get('/api/health/admin/users');
      return response.data.users;
    } catch (error) {
      console.error('Failed to get users:', error);
      throw error;
    }
  }

  /**
   * Get available data dates for a user
   */
  async getDates(username: string): Promise<string[]> {
    try {
      const response = await this.client.get('/api/health/admin/dates', {
        params: { username },
      });
      return response.data.dates;
    } catch (error) {
      console.error(`Failed to get dates for ${username}:`, error);
      throw error;
    }
  }

  /**
   * Fetch decrypted data for a user
   */
  async fetchDecryptedData(
    username: string,
    startDate?: string,
    endDate?: string
  ): Promise<any[]> {
    try {
      const params: any = { username };
      if (startDate) params.startDate = startDate;
      if (endDate) params.endDate = endDate;

      const response = await this.client.get('/api/health/admin/fetch-decrypted', {
        params,
      });

      return response.data.data;
    } catch (error) {
      console.error(`Failed to fetch data for ${username}:`, error);
      throw error;
    }
  }

  /**
   * Process and store fetched data
   * Always overwrites existing data
   */
  async processAndStore(username: string, fetchedData: any[]): Promise<void> {
    for (const dayData of fetchedData) {
      const { date } = dayData;

      try {
        // Save to local storage (always overwrite)
        await saveHealthData(username, date, dayData);

        // Check if this is an overwrite
        const existing = await getAvailableDates(username);
        const wasOverwritten = existing.includes(date);

        if (wasOverwritten) {
          console.log(`  ✓ Updated ${date} (overwritten)`);
        } else {
          console.log(`  ✓ Stored ${date}`);
        }
      } catch (error) {
        console.error(`  ✗ Failed to store ${date}:`, error);
      }
    }
  }

  /**
   * Fetch all data for all users
   */
  async fetchAll(): Promise<void> {
    ensureWorkspace();

    console.log('Fetching available users...');
    const users = await this.getUsers();
    console.log(`Found users: ${users.join(', ')}\n`);

    for (const username of users) {
      console.log(`Fetching data for ${username}...`);

      try {
        const data = await this.fetchDecryptedData(username);
        console.log(`  Fetched ${data.length} days of data`);

        await this.processAndStore(username, data);

        // Show summary
        const summary = await getDataSummary(username);
        console.log(`  Summary: ${summary.totalDays} days, ${(summary.totalSize / 1024).toFixed(2)} KB`);
      } catch (error) {
        console.error(`  Failed to fetch data for ${username}:`, error);
      }
    }
  }

  /**
   * Fetch today's data only
   */
  async fetchToday(): Promise<void> {
    ensureWorkspace();

    const today = new Date().toISOString().split('T')[0];
    console.log(`Fetching today's data (${today})...\n`);

    const users = await this.getUsers();

    for (const username of users) {
      console.log(`Fetching ${username}...`);

      try {
        const data = await this.fetchDecryptedData(username, today, today);
        await this.processAndStore(username, data);
      } catch (error) {
        console.error(`  Failed:`, error);
      }
    }
  }

  /**
   * Fetch recent data (last N days)
   */
  async fetchRecent(days: number = 7): Promise<void> {
    ensureWorkspace();

    const endDate = new Date().toISOString().split('T')[0];
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000)
      .toISOString()
      .split('T')[0];

    console.log(`Fetching data from ${startDate} to ${endDate}...\n`);

    const users = await this.getUsers();

    for (const username of users) {
      console.log(`Fetching ${username}...`);

      try {
        const data = await this.fetchDecryptedData(username, startDate, endDate);
        console.log(`  Fetched ${data.length} days`);
        await this.processAndStore(username, data);
      } catch (error) {
        console.error(`  Failed:`, error);
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
      await fetcher.fetchToday();
      break;
    case 'recent':
      const days = parseInt(process.argv[3] || '7', 10);
      await fetcher.fetchRecent(days);
      break;
    case 'all':
      await fetcher.fetchAll();
      break;
    default:
      console.log(`Unknown mode: ${mode}`);
      console.log('Usage: npm start [today|recent|all] [days]');
      process.exit(1);
  }

  console.log('\nDone!');
}

main().catch(console.error);
