# HealthSync 环境配置拆分设计

**日期**: 2026-04-08  
**状态**: 已批准

## 背景

当前服务端和 iOS App 的配置将本地开发与生产环境混用：
- 服务端 `.env.example` 默认使用 Docker 路径（`file:/app/data/health-sync.db`），本地 `npm run dev` 时需要手动改值
- iOS `AppContainer.swift` 中 `Config.serverURL` 默认值硬编码为生产 URL，调试时需手动进 Settings 改 URL
- `cachedServerURL` 缓存机制存在 bug：Settings 修改 URL 后缓存不更新

## 目标

1. 服务端：拆分 local / production 配置，`npm run dev` 直接可用，无需手动改值
2. iOS：Debug 构建默认连接本地 Mac（局域网 IP），Release 构建默认连接生产环境

---

## 设计

### 1. 服务端环境拆分

#### 文件结构

```
server/health-sync-server/
├── .env                        # 生产部署用（Docker 环境，gitignored）
├── .env.example                # 生产配置模板（committed）
├── .env.development.local      # 本地开发配置（gitignored，已被 .env.*.local 覆盖）
└── .env.development.example    # 本地开发配置模板（committed，复制即用）
```

#### `.env.development.example` 内容（本地默认值）

```env
NODE_ENV=development
PORT=3000

# 本地 SQLite 数据库（相对路径，数据文件在项目目录内）
DATABASE_URL=file:./dev.db

# JWT Secrets - 本地测试用（生产环境必须替换！）
JWT_SECRET=local-dev-secret-not-for-production
JWT_REFRESH_SECRET=local-dev-refresh-secret-not-for-production
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=30d

# CORS - 本地开发允许所有来源
CORS_ORIGIN=*

# 数据保留天数
DATA_RETENTION_DAYS=90

# 限流（本地开发可放宽）
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=1000
```

#### `config/index.ts` 更新

dotenv 加载逻辑改为根据 NODE_ENV 自动选择 env 文件：

```typescript
import dotenv from 'dotenv';

// 优先加载环境专属配置，回退到 .env
const nodeEnv = process.env.NODE_ENV || 'development';
if (nodeEnv === 'development') {
    dotenv.config({ path: '.env.development.local' });
}
dotenv.config(); // fallback，不会覆盖已加载的值
```

#### `package.json` scripts 更新

```json
{
  "scripts": {
    "dev": "NODE_ENV=development tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    ...
  }
}
```

#### 本地开发工作流

```bash
cp .env.development.example .env.development.local  # 首次 setup
# 填入自己的 JWT_SECRET（本地随意填即可）
npm run dev  # 自动读取 .env.development.local
```

#### Prisma 本地 migrate 处理

Prisma CLI 默认只读 `.env`，不读 `.env.development.local`。新增 npm script：

```json
"prisma:migrate:dev": "dotenv -e .env.development.local -- prisma migrate dev",
"prisma:studio:dev": "dotenv -e .env.development.local -- prisma studio"
```

需安装 `dotenv-cli`：`npm install -D dotenv-cli`

---

### 2. iOS 环境配置拆分

#### `AppContainer.swift` - `Config` 修改

移除有 bug 的 `cachedServerURL`，改用 `#if DEBUG` 区分默认 URL：

```swift
enum Config {
    /// Debug 构建默认连接本地 Mac，Release 构建默认连接生产服务器
    static let defaultServerURL: String = {
        #if DEBUG
        return "http://192.168.1.100:3000"  // 替换为你 Mac 的局域网 IP
        #else
        return "https://markmager.cc/healthsync"
        #endif
    }()

    /// 读取 URL：UserDefaults 中有覆盖值时使用覆盖值，否则用 defaultServerURL
    static var serverURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? defaultServerURL
    }
}
```

> **为什么移除 `cachedServerURL`？**  
> `UserDefaults` 自身有缓存机制，无需二次缓存。原缓存导致 Settings 修改 URL 后 `Config.serverURL` 仍返回旧值（因为 `cachedServerURL` 不清空）。

#### 本地调试工作流

1. 查看 Mac 的局域网 IP：`ifconfig | grep "inet "` 或 System Settings → Network
2. 在 `Config.defaultServerURL` 的 `#if DEBUG` 分支里替换 IP
3. 用 Xcode Debug scheme 运行到 iPhone
4. iPhone 与 Mac 连接同一 WiFi 即可
5. 如需临时换 URL：在 App Settings 界面修改（优先级高于默认值）

#### Settings 界面建议（可选后续）

在设置页加「恢复默认」按钮，清除 UserDefaults 中的 `serverURL`，让 `Config.serverURL` 回到 `defaultServerURL`。

---

## 不在本次范围内

- Mac Mini `health-fetcher` 的配置不变（已稳定运行，指向生产环境）
- iOS 多环境 xcconfig 方案（当前 `#if DEBUG` 已满足需求，xcconfig 是未来升级路线）

## 实现顺序

1. 服务端：创建 `.env.development.example` → 更新 `config/index.ts` → 更新 `package.json dev` script → 更新 `.gitignore`（确认 `.env.development.local` 已被忽略）
2. iOS：修改 `AppContainer.swift` 中的 `Config` enum → 替换为自己 Mac 的 IP → Debug scheme 验证
