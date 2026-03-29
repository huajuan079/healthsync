# Health Fetcher - Mac Mini 数据拉取脚本

从服务器拉取**已解密**的健康数据，存储到本地供 AI 分析。

## 架构变化

**旧设计**：
- Mac Mini 使用用户账号登录
- Mac Mini 需要配置每个用户的加密密钥
- Mac Mini 自己解密数据

**新设计**：
- Mac Mini 使用 **API Key** 认证（专用管理员通道）
- 服务器端解密数据
- 返回**明文 JSON** 给 Mac Mini
- **不需要在 Mac Mini 上配置任何加密密钥**

---

## 配置

### 1. 服务器端配置

在服务器的 `.env` 中添加：

```bash
# Mac Mini 专用的 API Key
MAC_MINI_API_KEY=your-secret-api-key-here
```

### 2. Mac Mini 配置

创建 `.env`：

```bash
SERVER_URL=http://your-server-ip:3000
API_KEY=your-secret-api-key-here
WORKSPACE_PATH=~/.openclaw/workspace/health
```

---

## 使用

```bash
# 安装依赖
npm install

# 构建
npm run build

# 拉取所有数据
npm start all

# 拉取今天的数据
npm start today

# 拉取最近 N 天的数据
npm start recent 7
```

---

## API 端点

| 端点 | 说明 |
|------|------|
| `GET /api/health/admin/users` | 获取可用用户列表 |
| `GET /api/health/admin/dates?username=xxx` | 获取某用户的数据日期列表 |
| `GET /api/health/admin/fetch-decrypted` | 获取已解密的健康数据 |

---

## 数据存储格式

```
~/.openclaw/workspace/health/
├── zhugong/
│   ├── 2026-03-22.json
│   ├── 2026-03-23.json
│   └── ...
└── dage/
    ├── 2026-03-22.json
    └── ...
```

每日数据格式（明文 JSON）：

```json
{
  "date": "2026-03-29",
  "user": "zhugong",
  "sync_time": "2026-03-29T10:00:00+08:00",
  "sleep": [
    {
      "startDate": "2026-03-28T23:00:00+08:00",
      "endDate": "2026-03-29T07:00:00+08:00",
      "type": "asleep",
      "source": "Watch"
    }
  ],
  "heart_rate": [
    {
      "timestamp": "2026-03-29T08:00:00+08:00",
      "value": 72,
      "unit": "bpm"
    }
  ],
  "steps": {
    "date": "2026-03-29",
    "value": 8542
  }
}
```

---

## 定时任务

```bash
crontab -e

# 每天凌晨 1 点拉取前一天的数据
0 1 * * * cd /path/to/health-fetcher && npm start today >> ~/.openclaw/logs/fetcher.log 2>&1
```
