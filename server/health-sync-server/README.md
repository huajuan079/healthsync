# Health Sync Server

健康数据同步服务器 - 腾讯云中转服务

## 功能

- JWT认证
- AES-256-GCM数据加密
- 分批数据上传
- 7天数据自动清理
- 用户数据隔离

## 环境变量

```bash
# 服务器配置
PORT=3000
NODE_ENV=production

# JWT配置
JWT_SECRET=your-secret-key
JWT_REFRESH_SECRET=your-refresh-secret
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=30d

# 加密密钥 (32字节 = 64个十六进制字符)
ENCRYPTION_KEY_ZHUGONG=0000000000000000000000000000000000000000000000000000000000000000
ENCRYPTION_KEY_DAGE=0000000000000000000000000000000000000000000000000000000000000000

# 数据保留天数
DATA_RETENTION_DAYS=7

# CORS
CORS_ORIGIN=*
```

## API 接口

### 认证

```
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/auth/me
```

### 健康数据

```
POST /api/health/upload    - 上传加密数据
GET  /api/health/status    - 获取同步状态
GET  /api/health/fetch     - 拉取数据 (Mac Mini)
DELETE /api/health/cleanup - 清理旧数据 (管理员)
```

## 数据库

使用 Prisma + SQLite：

```bash
npm run prisma:studio   # 打开数据库管理界面
npm run prisma:migrate  # 运行迁移
```

## 部署

```bash
npm install
npm run build
npm start
```

使用 PM2 守护进程：

```bash
pm2 start dist/server.js --name health-sync-server
pm2 startup
pm2 save
```

## 生成加密密钥

```bash
# 生成32字节随机密钥
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```
