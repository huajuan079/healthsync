# 健康数据同步系统

完整的健康数据同步系统，支持将iPhone HealthKit数据加密上传到腾讯云服务器，再由Mac Mini定时拉取归档，供AI助手"小炎"进行健康分析。

## 系统架构

```
iPhone App (HealthSync) → 腾讯云服务器 (中转+7天缓冲) → Mac Mini (长期归档+小炎分析)
```

## 项目结构

```
health-sync-system/
├── server/                    # Node.js + TypeScript 服务器
│   └── health-sync-server/
├── ios/                       # iOS App (Swift + SwiftUI)
│   └── HealthSync/
└── mac-mini/                  # Mac Mini 拉取脚本
    └── health-fetcher/
```

## 功能特性

### 服务器 (Node.js + TypeScript)
- JWT认证机制
- AES-256-GCM数据加密
- 分批上传支持
- 7天数据自动清理
- SQLite数据库

### iOS App (Swift + SwiftUI)
- HealthKit数据读取（睡眠、心率、步数、运动等）
- 本地AES加密
- 后台定时同步
- 深色主题界面
- 同步状态追踪

### Mac Mini脚本
- 数据拉取和解密
- 本地JSON存储
- 可配置定时任务

## 快速开始

### 1. 服务器部署

```bash
cd server/health-sync-server
npm install
cp .env.example .env
# 编辑 .env 配置密钥
npm run prisma:migrate
npm run dev
```

默认用户：
- 主公: `zhugong` / `zhugong123`
- 大哥: `dage` / `dage123`

### 2. iOS App

1. 在Xcode中打开 `ios/HealthSync/HealthSync.xcodeproj`
2. 修改服务器地址（在SettingsView中）
3. 配置签名和证书
4. 运行到真机（需要HealthKit权限）

### 3. Mac Mini脚本

```bash
cd mac-mini/health-fetcher
npm install
cp .env.example .env
# 配置服务器地址和加密密钥
npm run build
npm start # 或 'today' 只同步今天
```

配置cron定时任务：
```bash
0 23 * * * cd ~/.openclaw/health-fetcher && npm start
```

## 安全设计

- **传输安全**: HTTPS全程加密
- **数据加密**: AES-256-GCM
- **认证方式**: JWT Token + 自动刷新
- **密钥管理**: 加密密钥仅存Mac Mini本地
- **数据隔离**: 用户数据完全独立存储

## 数据类型支持

| 类型 | 说明 |
|------|------|
| 睡眠 | 睡眠分析、深睡浅睡 |
| 心率 | 实时心率、静息心率 |
| HRV | 心率变异性 |
| 步数 | 每日步数、行走距离 |
| 运动 | 运动类型、时长、消耗 |
| 血氧 | 血氧饱和度 |
| 体重 | 体重、BMI |
| 冥想 | 正念会话记录 |

## 技术栈

**服务器**: Node.js, TypeScript, Express, Prisma, SQLite, bcrypt, jsonwebtoken

**iOS**: Swift, SwiftUI, HealthKit, CryptoKit, BackgroundTasks

**Mac Mini**: TypeScript, Axios, Crypto

## 开发进度

- [x] 服务器基础设施
- [x] iOS App 基础架构
- [x] 认证模块
- [x] HealthKit 数据读取
- [x] 加密模块
- [x] 同步模块
- [x] 主界面和设置
- [x] Mac Mini 脚本

## 许可证

MIT License
