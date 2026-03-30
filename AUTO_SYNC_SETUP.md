# 健康数据自动同步流程配置指南

## 完整流程概览

```
iPhone (每天 10:00) → 服务器 (自动转发) → Mac Mini (每天 10:15) → 长期归档
    ↓ 后台同步           ↓ 自动清理 (3:00)      ↓ cron 定时任务
```

## 数据同步策略

**iPhone - 每天早上 10:00 同步：**
- 昨天完整数据（包括昨晚睡眠、运动等）
- 今天0-10点数据（包括今早睡眠、体重等）

**Mac Mini - 每天早上 10:15 获取：**
- 从服务器获取最近 2 天数据
- 覆盖本地文件，保持最新

**数据完整性保证：**
- 昨晚的睡眠 ✓
- 昨天的运动 ✓
- 昨天的步数 ✓
- 今早的睡眠 ✓
- 今早的体重 ✓
- 今天的运动（如果有）✓

## 1. iPhone 端 - 后台自动同步 ✅

### 工作原理
- **时间**：每天早上 10:00 自动执行
- **方式**：iOS Background Tasks
- **同步内容**：昨天 + 今天的数据
- **上传位置**：腾讯云服务器

### 自动激活
App 首次启动时会自动注册后台同步任务，无需手动配置。

### 验证方法
1. 打开 iPhone 设置 → 通用 → 后台App刷新
2. 找到 "HealthSync"，确保开启
3. 早上 10 点后检查首页是否显示 "上次同步: 今天"

## 2. 服务器端 - 自动清理旧数据 ✅

### 工作原理
- **时间**：每天凌晨 3:00 自动执行
- **方式**：node-cron 定时任务
- **清理内容**：删除 90 天前的数据
- **保留策略**：每个用户保留最近 90 天数据

### 服务器日志
```
[INFO] Cleanup job scheduled to run daily at 2:00 AM
[INFO] Starting daily cleanup job...
[INFO] Completed cleanup of all users data
[INFO] Daily cleanup job completed successfully
```

## 3. Mac Mini - 自动获取并归档 ✅

### 配置步骤

#### 3.1 安装依赖（首次）
```bash
cd ~/.openclaw/health-fetcher
npm install
npm run build
```

#### 3.2 设置 Cron 定时任务
```bash
# 编辑 crontab
crontab -e

# 添加以下行（修改 npm 路径为你的实际路径）：
15 10 * * * cd ~/.openclaw/health-fetcher && /usr/local/bin/npm start recent 2 >> ~/.openclaw/health-fetcher/logs/cron.log 2>&1
```

#### 3.3 验证配置
```bash
# 查看 crontab
crontab -l

# 查找 npm 路径
which npm
# 输出示例: /usr/local/bin/npm

# 创建日志目录
mkdir -p ~/.openclaw/health-fetcher/logs

# 手动测试（获取最近2天）
npm start recent 2
```

#### 3.4 监控日志
```bash
# 实时查看日志
tail -f ~/.openclaw/health-fetcher/logs/cron.log

# 查看最近 50 行
tail -n 50 ~/.openclaw/health-fetcher/logs/cron.log
```

## 完整时间线

| 时间 | iPhone | 服务器 | Mac Mini |
|------|--------|--------|----------|
| 10:00 | **开始后台同步** ✅ | 接收并存储 ✅ | 等待 |
| 10:01 | 昨天数据上传完成 | 昨天数据可获取 | 等待 |
| 10:02 | 今天数据上传完成 | 今天数据可获取 | 等待 |
| 10:03 | 完成同步，休眠 | 2天数据可获取 | 等待 |
| 10:15 | 休眠 | 数据可获取 | **开始获取** ✅ |
| 10:16 | 休眠 | 数据可获取 | 覆盖本地文件 ✅ |
| 03:00 | 休眠 | **自动清理旧数据** ✅ | 休眠 |

## 故障排查

### iPhone 没有自动同步
1. 检查后台App刷新是否开启
2. 确保已登录 App
3. 检查网络连接
4. 手动触发一次同步：打开首页 → 点击"立即同步今日数据"

### Mac Mini 没有获取数据
1. 检查 cron 是否运行：`crontab -l`
2. 查看 cron 日志：`tail -f ~/.openclaw/health-fetcher/logs/cron.log`
3. 手动测试：`cd ~/.openclaw/health-fetcher && npm start`
4. 检查服务器连接：`curl https://your-server.com/api/health/healthcheck`

### 服务器没有自动清理
1. 查看服务器日志：`journalctl -u health-sync -f`（如果使用 systemd）
2. 重启服务器：`npm run start`
3. 手动清理：调用 DELETE /api/health/cleanup API

## 数据流验证

### 1. 验证 iPhone 上传
```bash
# 在 iPhone App 设置中查看同步状态
# 或在首页查看"上次同步"时间
```

### 2. 验证服务器数据
```bash
# SSH 到服务器
cd /path/to/health-sync-server/storage/health_data
ls -lh zhugong/ dage/
```

### 3. 验证 Mac Mini 归档
```bash
# 在 Mac Mini 上
ls -lh ~/.openclaw/workspace/health/zhugong/
ls -lh ~/.openclaw/workspace/health/dage/
```

## 维护建议

### 每周检查
- [ ] Mac Mini 磁盘空间
- [ ] 服务器存储空间
- [ ] 同步日志是否正常

### 每月检查
- [ ] 数据完整性（随机抽查几天的数据）
- [ ] 备份 Mac Mini 上的健康数据

## 修改同步时间

### 修改 iPhone 同步时间
编辑文件：`ios/HealthSync/HealthSync/Modules/Sync/Background/BackgroundSyncTask.swift`
```swift
dateComponents.hour = 23  // 修改为想要的小时
dateComponents.minute = 0  // 修改为想要的分钟
```

### 修改 Mac Mini 同步时间
```bash
crontab -e
# 修改时间：30 23 * * * (改为其他时间)
```

### 修改服务器清理时间
编辑文件：`server/health-sync-server/src/jobs/cleanup.job.ts`
```typescript
this.task = cron.schedule('0 2 * * *', ...); // 修改 2 为其他小时
```

## 完成

现在整个自动同步流程已经打通：
- ✅ iPhone 每天自动上传
- ✅ 服务器自动清理旧数据
- ✅ Mac Mini 自动获取并归档

你的健康数据会自动、安全地从 iPhone 流转到 Mac Mini，供小炎 AI 分析使用！
