# Health Fetcher - Mac Mini 数据拉取脚本

从腾讯云服务器拉取并解密健康数据，存储到本地供AI助手分析。

## 配置

创建 `~/.openclaw/keys/health_sync.json`:

```json
{
  "zhugong": "0000000000000000000000000000000000000000000000000000000000000000",
  "dage": "0000000000000000000000000000000000000000000000000000000000000000"
}
```

修改 `.env`:

```bash
SERVER_URL=https://your-server.com
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
WORKSPACE_PATH=~/.openclaw/workspace/health
```

## 使用

```bash
# 安装依赖
npm install

# 构建
npm run build

# 拉取所有数据
npm start

# 只拉取今天的数据
npm start today

# 开发模式
npm run dev
```

## 定时任务

配置cron每天23:30执行：

```bash
crontab -e

# 添加以下行
30 23 * * * cd /path/to/health-fetcher && npm start >> ~/.openclaw/logs/fetcher.log 2>&1
```

## 数据存储格式

```
~/.openclaw/workspace/health/
├── zhugong/
│   ├── 2026-03-26.json
│   └── 2026-03-27.json
└── dage/
    ├── 2026-03-26.json
    └── 2026-03-27.json
```

每日数据格式：

```json
{
  "date": "2026-03-26",
  "user": "zhugong",
  "sync_time": "2026-03-26T23:00:00+08:00",
  "sleep": [...],
  "heart_rate": [...],
  "hrv": [...],
  "steps": [...],
  "workouts": [...],
  "blood_oxygen": [...]
}
```

## 集成小炎AI

小炎可以从本地JSON文件读取健康数据进行分析：

```python
import json
from pathlib import Path

def load_health_data(username, date):
    path = Path(f"~/.openclaw/workspace/health/{username}/{date}.json").expanduser()
    with open(path) as f:
        return json.load(f)

# 使用数据
data = load_health_data("zhugong", "2026-03-26")
print(f"今日步数: {data['steps'][0]['value']}")
```
