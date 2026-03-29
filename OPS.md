# HealthSync 运维手册

## 服务信息

| 项目 | 内容 |
|------|------|
| 服务器 IP | 129.226.145.68 |
| SSH 密钥 | `~/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem` |
| 用户名 | root |
| API 地址 | https://markmager.cc/healthsync |
| 容器名 | health-sync-server |
| 源码路径 | /opt/health-sync/ |

---

## 快速命令

### SSH 登录
```bash
ssh -i ~/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem root@129.226.145.68
```

### 查看容器状态
```bash
ssh -i ~/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem root@129.226.145.68 "docker ps"
```

### 查看实时日志
```bash
ssh -i ~/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem root@129.226.145.68 "docker logs -f health-sync-server"
```

### 重启服务
```bash
ssh -i ~/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem root@129.226.145.68 "docker restart health-sync-server"
```

### 测试 API 是否正常
```bash
curl https://markmager.cc/healthsync/api/health/healthcheck
```

---

## 重新部署（代码更新后）

```bash
cd ~/Documents/Code/private/healthsync
bash server/deploy.sh
```

---

## Nginx 配置更新（零停机热重载）

```bash
# 1. 编辑本地配置
vim /opt/markmager-web/nginx-https.conf

# 2. 复制进容器
docker cp /opt/markmager-web/nginx-https.conf markmager-web:/etc/nginx/conf.d/default.conf

# 3. 测试语法
docker exec markmager-web nginx -t

# 4. 热重载
docker exec markmager-web nginx -s reload
```

---

## 数据库操作

### 进入容器
```bash
ssh -i ~/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem root@129.226.145.68 "docker exec -it health-sync-server sh"
```

### 查看 SQLite 数据库
```bash
# 进入容器后
npx prisma studio   # 不适用于无头环境，用下面的方式
sqlite3 /app/data/health-sync.db ".tables"
sqlite3 /app/data/health-sync.db "SELECT username, role FROM User;"
```

### 查看数据卷
```bash
ssh -i ~/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem root@129.226.145.68 "docker volume ls | grep health-sync"
```

---

## 常见问题排查

### 问题：API 返回 502 Bad Gateway
```bash
# 检查 health-sync 容器是否在运行
docker ps | grep health-sync-server

# 查看容器日志
docker logs --tail 50 health-sync-server

# 重启容器
docker restart health-sync-server
```

### 问题：Nginx 无法代理到 health-sync
```bash
# 在 markmager-web 容器内测试连通性
docker exec markmager-web curl http://health-sync-server:3000/api/health/healthcheck
```

### 问题：JWT 认证失败（Token invalid）
```bash
# 查看当前 .env 配置（不显示密钥内容，只确认存在）
ssh -i ... root@129.226.145.68 "grep -c JWT_SECRET /opt/health-sync/.env"
```

### 问题：服务器重启后容器没有自动启动
```bash
# 容器已配置 restart: unless-stopped，手动启动：
docker start health-sync-server
```

---

## Mac Mini 脚本操作

### 手动拉取今天的数据
```bash
cd ~/.openclaw/health-fetcher
npm start today
```

### 手动拉取所有数据
```bash
cd ~/.openclaw/health-fetcher
npm start
```

### 查看已归档数据
```bash
ls ~/.openclaw/workspace/health/zhugong/
ls ~/.openclaw/workspace/health/dage/
```

### 定时任务配置（每天 23:00 自动拉取）
```bash
crontab -e
# 添加：
0 23 * * * cd ~/.openclaw/health-fetcher && npm start >> ~/.openclaw/health-fetcher.log 2>&1
```

---

## 架构图

```
iPhone (HealthKit)
    │  AES-256-GCM 加密
    ▼
https://markmager.cc/healthsync/api/...
    │  Nginx 反向代理 (markmager-web 容器)
    ▼
http://health-sync-server:3000 (Docker 容器)
    │  SQLite 存储加密数据，保留 7 天
    ▼
Mac Mini (health-fetcher 每天 23:00 拉取)
    │  解密并保存为日期 JSON 文件
    ▼
~/.openclaw/workspace/health/用户名/YYYY-MM-DD.json
```
