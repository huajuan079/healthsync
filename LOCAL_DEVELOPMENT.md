# Local Development Guide

## Server (本地启动)

**首次 setup（只需一次）：**
```bash
cd server/health-sync-server
cp .env.development.example .env.development.local
# 编辑 .env.development.local，可保持默认值（JWT secret 本地随意）
npm install
npm run prisma:migrate:dev   # 创建本地 dev.db
npm run db:seed               # 初始化用户数据
```

**日常启动：**
```bash
cd server/health-sync-server
npm run dev
# 输出 "Environment: development" 表示读取了本地配置
# 服务运行在 http://localhost:3000
```

**本地默认账号（seed 数据）：**
- `zhugong` / `zhugong123`
- `dage` / `dage123`

**Prisma 相关（本地）：**
```bash
npm run prisma:migrate:dev   # 跑 migration（读 .env.development.local）
npm run prisma:studio:dev    # 打开数据库 GUI
```

---

## iOS App (连接本地服务)

**前置条件：**
- iPhone 和 Mac 在同一 WiFi
- 本地服务端已启动

**查看 Mac IP：**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
# 取 192.168.x.x 格式的地址（WiFi 网卡）
```

**如果 IP 变了，更新代码：**

文件：`ios/HealthSync/HealthSync/Core/DI/AppContainer.swift`

```swift
#if DEBUG
return "http://192.168.124.81:3000"  // ← 改这里
```

**构建：** 用 Xcode Debug scheme (⌘+R)，默认连接本地 Mac。

**临时切换 URL：** App 内 Settings → Server URL（UserDefaults 优先级高于默认值）。

---

## 环境说明

| 环境 | 服务端 | iOS 默认 URL |
|------|--------|-------------|
| 本地开发 | `npm run dev` + `.env.development.local` | `http://192.168.x.x:3000` (Debug build) |
| 生产 | Docker + `.env` | `https://markmager.cc/healthsync` (Release build) |

**注意：** `.env.development.local` 已被 `.gitignore` 忽略，不会提交到仓库。
