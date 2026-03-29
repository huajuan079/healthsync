import { Request, Response, NextFunction } from 'express';
import { HealthService } from '../services/health.service';
import { createLogger } from '../utils/logger';
import { prisma } from '../models/prisma';

const logger = createLogger('HealthController');
const healthService = new HealthService();

export class HealthController {
  /**
   * POST /health/upload
   */
  async upload(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const username = req.user?.username;
      const userId = req.user?.userId;

      if (!username || !userId) {
        res.status(401).json({ error: 'Not authenticated' });
        return;
      }

      const result = await healthService.uploadBatch(username, userId, req.body);

      res.json({
        success: true,
        batch_id: result.batchId,
        message: result.message,
      });
    } catch (error) {
      logger.error('Upload error', { error });
      if (error instanceof Error) {
        res.status(400).json({ success: false, error: error.message });
      } else {
        next(error);
      }
    }
  }

  /**
   * GET /health/status
   */
  async status(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const username = req.user?.username;
      const userId = req.user?.userId;

      if (!username || !userId) {
        res.status(401).json({ error: 'Not authenticated' });
        return;
      }

      const status = await healthService.getSyncStatus(userId, username);

      res.json(status);
    } catch (error) {
      logger.error('Status error', { error });
      next(error);
    }
  }

  /**
   * GET /health/fetch - For Mac Mini to pull data
   */
  async fetch(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { username, startDate, endDate } = req.query;

      if (!username || typeof username !== 'string') {
        res.status(400).json({ error: 'Username is required' });
        return;
      }

      // Verify user exists
      const data = await healthService.fetchData(
        username,
        startDate as string,
        endDate as string
      );

      res.json({
        success: true,
        username,
        count: data.length,
        data,
      });
    } catch (error) {
      logger.error('Fetch error', { error });
      next(error);
    }
  }

  /**
   * DELETE /health/cleanup - Clean up old data
   */
  async cleanup(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      // Admin only endpoint
      if (req.user?.role !== 'admin') {
        res.status(403).json({ error: 'Admin access required' });
        return;
      }

      const { StorageService } = await import('../services/storage.service.js');
      const storage = new StorageService();

      await storage.cleanupAllUsersData();

      res.json({ success: true, message: 'Cleanup completed' });
    } catch (error) {
      logger.error('Cleanup error', { error });
      next(error);
    }
  }

  /**
   * GET /health/healthcheck - Health check endpoint
   */
  async healthcheck(req: Request, res: Response): Promise<void> {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  }

  /**
   * GET /health/web/uploads - Web interface to view uploads
   */
  async viewUploads(req: Request, res: Response): Promise<void> {
    try {
      // Get all users and their uploads
      const users = await prisma.user.findMany({
        include: {
          uploads: {
            orderBy: { createdAt: 'desc' },
            take: 50,
          },
          syncStatus: true,
        },
      });

      // Generate HTML page
      const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>HealthSync - 上传记录</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f5f5f5;
      padding: 20px;
      line-height: 1.6;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    h1 { color: #333; margin-bottom: 20px; }
    .user-section {
      background: white;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    .user-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 15px;
      padding-bottom: 15px;
      border-bottom: 2px solid #eee;
    }
    .user-name {
      font-size: 20px;
      font-weight: 600;
      color: #2c3e50;
    }
    .sync-status {
      font-size: 14px;
      color: #666;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }
    th, td {
      padding: 12px;
      text-align: left;
      border-bottom: 1px solid #eee;
    }
    th {
      background: #f8f9fa;
      font-weight: 600;
      color: #555;
    }
    tr:hover { background: #f8f9fa; }
    .status-completed { color: #27ae60; font-weight: 500; }
    .status-pending { color: #f39c12; font-weight: 500; }
    .status-failed { color: #e74c3c; font-weight: 500; }
    .no-data {
      text-align: center;
      color: #999;
      padding: 40px;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 15px;
      margin-bottom: 20px;
    }
    .stat-card {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 15px;
      border-radius: 8px;
      text-align: center;
    }
    .stat-value {
      font-size: 24px;
      font-weight: bold;
    }
    .stat-label {
      font-size: 12px;
      opacity: 0.9;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🩺 HealthSync 上传记录</h1>

    <div class="stats">
      <div class="stat-card">
        <div class="stat-value">${users.length}</div>
        <div class="stat-label">用户总数</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${users.reduce((sum: number, u) => sum + u.uploads.length, 0)}</div>
        <div class="stat-label">上传记录</div>
      </div>
    </div>

    ${users.map(user => `
    <div class="user-section">
      <div class="user-header">
        <div class="user-name">👤 ${user.username}</div>
        <div class="sync-status">
          最后同步: ${user.syncStatus?.[0]?.lastSyncAt ? new Date(user.syncStatus[0].lastSyncAt).toLocaleString('zh-CN') : '从未同步'}
        </div>
      </div>

      ${user.uploads.length === 0 ?
        '<div class="no-data">暂无上传记录</div>' :
        `<table>
          <thead>
            <tr>
              <th>日期</th>
              <th>批次</th>
              <th>记录数</th>
              <th>文件大小</th>
              <th>状态</th>
              <th>上传时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            ${user.uploads.map(upload => `
            <tr>
              <td>${upload.date}</td>
              <td>${upload.batchIndex + 1} / ${upload.batchTotal}</td>
              <td>${upload.recordCount}</td>
              <td>${(upload.fileSize / 1024).toFixed(1)} KB</td>
              <td class="status-${upload.status}">${upload.status === 'completed' ? '✅ 完成' : upload.status === 'pending' ? '⏳ 处理中' : '❌ 失败'}</td>
              <td>${new Date(upload.createdAt).toLocaleString('zh-CN')}</td>
              <td><a href="/healthsync/api/health/web/upload/${upload.id}" style="color: #667eea; text-decoration: none;">👁️ 查看</a></td>
            </tr>
            `).join('')}
          </tbody>
        </table>`
      }
    </div>
    `).join('')}
  </div>
</body>
</html>`;

      res.send(html);
    } catch (error) {
      logger.error('View uploads error', { error });
      res.status(500).send('Error loading upload records');
    }
  }

  /**
   * GET /health/web/upload/:id - View upload detail
   */
  async viewUploadDetail(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;

      const upload = await prisma.upload.findUnique({
        where: { id: id as string },
        include: { user: true },
      }) as any;

      if (!upload) {
        res.status(404).send('Upload record not found');
        return;
      }

      // Try to read the stored plaintext file
      let filePreview = '';
      let fileExists = false;

      try {
        const { StorageService } = await import('../services/storage.service.js');
        const storage = new StorageService();
        const data = await storage.readPlaintextData(upload.user.username, upload.date);
        fileExists = true;

        // Show first 200 chars of plaintext data
        filePreview = data.substring(0, 200) + (data.length > 200 ? '...' : '');
      } catch (e) {
        filePreview = '文件读取失败或已被归档删除';
      }

      const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>HealthSync - 上传详情</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f5f5f5;
      padding: 20px;
      line-height: 1.6;
    }
    .container { max-width: 800px; margin: 0 auto; }
    h1 { color: #333; margin-bottom: 20px; }
    .back-link {
      display: inline-block;
      margin-bottom: 20px;
      color: #667eea;
      text-decoration: none;
    }
    .back-link:hover { text-decoration: underline; }
    .detail-card {
      background: white;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    .detail-row {
      display: flex;
      padding: 12px 0;
      border-bottom: 1px solid #eee;
    }
    .detail-row:last-child { border-bottom: none; }
    .detail-label {
      width: 120px;
      color: #666;
      font-weight: 500;
    }
    .detail-value {
      flex: 1;
      color: #333;
    }
    .status-completed { color: #27ae60; font-weight: 500; }
    .status-pending { color: #f39c12; font-weight: 500; }
    .status-failed { color: #e74c3c; font-weight: 500; }
    .preview-box {
      background: #f8f9fa;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      padding: 15px;
      margin-top: 10px;
      font-family: 'Courier New', monospace;
      font-size: 12px;
      word-break: break-all;
      max-height: 300px;
      overflow-y: auto;
    }
    .decrypted-box {
      background: #f0f9eb;
      border: 1px solid #b3e19d;
      border-radius: 8px;
      padding: 15px;
      margin-top: 10px;
      font-family: 'Courier New', monospace;
      font-size: 12px;
      word-break: break-all;
      max-height: 500px;
      overflow-y: auto;
    }
    .info-box {
      background: #e3f2fd;
      border-left: 4px solid #2196f3;
      padding: 15px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .info-box h3 {
      color: #1976d2;
      margin-bottom: 10px;
    }
    .info-box p {
      color: #555;
      font-size: 14px;
    }
    .success-box {
      background: #f0f9eb;
      border-left: 4px solid #67c23a;
      padding: 15px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .success-box h3 {
      color: #67c23a;
      margin-bottom: 10px;
    }
    .error-box {
      background: #fef0f0;
      border-left: 4px solid #f56c6c;
      padding: 15px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .error-box h3 {
      color: #f56c6c;
      margin-bottom: 10px;
    }
  </style>
</head>
<body>
  <div class="container">
    <a href="/healthsync/api/health/web/uploads" class="back-link">← 返回列表</a>
    <h1>📄 上传记录详情</h1>

    <div class="detail-card">
      <div class="detail-row">
        <div class="detail-label">记录ID</div>
        <div class="detail-value">${upload.id}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">用户</div>
        <div class="detail-value">${upload.user.username}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">日期</div>
        <div class="detail-value">${upload.date}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">批次</div>
        <div class="detail-value">${upload.batchIndex + 1} / ${upload.batchTotal}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">记录数</div>
        <div class="detail-value">${upload.recordCount}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">文件大小</div>
        <div class="detail-value">${upload.fileSize} 字节 (${(upload.fileSize / 1024).toFixed(2)} KB)</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">状态</div>
        <div class="detail-value status-${upload.status}">${upload.status === 'completed' ? '✅ 完成' : upload.status === 'pending' ? '⏳ 处理中' : '❌ 失败'}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">校验和</div>
        <div class="detail-value" style="font-family: monospace; font-size: 12px;">${upload.checksum}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">上传时间</div>
        <div class="detail-value">${new Date(upload.createdAt).toLocaleString('zh-CN')}</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">更新时间</div>
        <div class="detail-value">${new Date(upload.updatedAt).toLocaleString('zh-CN')}</div>
      </div>
      ${upload.errorMessage ? `
      <div class="detail-row">
        <div class="detail-label">错误信息</div>
        <div class="detail-value" style="color: #e74c3c;">${upload.errorMessage}</div>
      </div>
      ` : ''}
    </div>

    <div class="detail-card">
      <h3>📄 健康数据预览</h3>
      <div class="info-box">
        <h3>ℹ️ 关于数据存储</h3>
        <p>健康数据以明文 JSON 格式存储。</p>
      </div>
      <div class="preview-box">
        ${fileExists ? filePreview : '文件不存在或已被归档删除'}
      </div>
    </div>
  </div>
</body>
</html>`;

      res.send(html);
    } catch (error) {
      logger.error('View upload detail error', { error });
      res.status(500).send('Error loading upload detail');
    }
  }

  /**
   * GET /health/admin/fetch-decrypted
   * Fetch health data for Mac Mini (authenticated by API Key)
   * Returns plaintext JSON
   */
  async adminFetchDecrypted(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { username, startDate, endDate } = req.query;

      if (!username || typeof username !== 'string') {
        res.status(400).json({ error: 'Username is required' });
        return;
      }

      // Get plaintext data from storage
      const { StorageService } = await import('../services/storage.service.js');
      const storage = new StorageService();

      let dates = await storage.getAvailableDates(username);

      // Filter by date range if provided
      if (startDate) {
        dates = dates.filter((d: string) => d >= (startDate as string));
      }
      if (endDate) {
        dates = dates.filter((d: string) => d <= (endDate as string));
      }

      const result = [];

      for (const date of dates) {
        try {
          // Read plaintext data directly
          const plaintextData = await storage.readPlaintextData(username, date);
          const data = JSON.parse(plaintextData);

          // Map iOS format to internal format
          const mappedData: any = {
            date,
            user: username,
            sync_time: new Date().toISOString(),
            sleep: data.sleep || [],
            heart_rate: data.heartRate || [],
            resting_heart_rate: data.restingHeartRate || null,
            hrv: data.hrv || [],
            steps: data.steps || null,
            workouts: data.workouts || [],
            blood_oxygen: data.bloodOxygen || [],
            menstrual: data.menstrual || [],
            weight: data.weight || null,
            medications: data.medications || [],
            mindfulness: data.mindfulness || [],
          };

          result.push(mappedData);
        } catch (error) {
          logger.error(`Failed to process data for ${username} on ${date}:`, error);
        }
      }

      logger.info(`Admin fetch plaintext: ${username}, ${result.length} days`);

      res.json({
        success: true,
        username,
        count: result.length,
        data: result,
      });
    } catch (error) {
      logger.error('Admin fetch plaintext error', { error });
      next(error);
    }
  }

  /**
   * GET /health/admin/users
   * Get list of available users (for Mac Mini discovery)
   */
  async adminGetUsers(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const users = await prisma.user.findMany({
        where: { isActive: true },
        select: { username: true },
      });

      res.json({
        success: true,
        users: users.map((u: { username: string }) => u.username),
      });
    } catch (error) {
      logger.error('Admin get users error', { error });
      next(error);
    }
  }

  /**
   * GET /health/admin/dates
   * Get available data dates for a user
   */
  async adminGetDates(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { username } = req.query;

      if (!username || typeof username !== 'string') {
        res.status(400).json({ error: 'Username is required' });
        return;
      }

      const { StorageService } = await import('../services/storage.service.js');
      const storage = new StorageService();

      const dates = await storage.getAvailableDates(username);

      res.json({
        success: true,
        username,
        dates,
      });
    } catch (error) {
      logger.error('Admin get dates error', { error });
      next(error);
    }
  }
}

export const healthController = new HealthController();
