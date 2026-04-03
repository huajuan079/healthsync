# Security Risks

> 审查日期：2026-03-31

---

## 严重 (Critical)

### 1. 公开的健康数据接口 — 无需认证

**位置**: `server/health-sync-server/src/routes/health.routes.ts`

以下路由没有任何认证保护，任何人都能访问：

```
GET /api/health/fetch?username=zhugong  ← 可查询任意用户数据
GET /api/health/web/uploads             ← 暴露所有用户上传记录
GET /api/health/web/upload/:id          ← 暴露单条上传详情
```

**修复方案**: 给这些路由加上 `authMiddleware`。

---

### 2. 硬编码默认用户密码

**位置**: `server/health-sync-server/src/services/auth.service.ts:136-137`

```ts
{ username: 'zhugong', password: 'zhugong123' },
{ username: 'dage',    password: 'dage123'    },
```

种子脚本会自动创建这些账户，密码还会打印到日志。

**修复方案**: 删除硬编码密码，改为环境变量或首次启动时强制设置。

---

## 高危 (High)

### 3. 健康数据明文存储在服务器

**位置**: `server/health-sync-server/src/services/storage.service.ts`

代码注释明确写 "no encryption"，数据以 JSON 文件存储在 `./storage/health_data/`。
服务器被入侵或磁盘被物理访问时，所有健康数据完全暴露。
此行为也与 CLAUDE.md 文档描述的"端到端加密"不符。

**修复方案**: 存储前用 AES-256-GCM 加密，或缩短服务器保留时间。

---

### 4. CORS 默认允许所有来源

**位置**: `server/health-sync-server/src/app.ts`

```ts
origin: process.env.CORS_ORIGIN || '*'
```

如果 `.env` 未配置 `CORS_ORIGIN`，等于对所有域名开放。

**修复方案**: 在 `.env` 中配置具体白名单域名。

---

### 5. iOS 实际未加密上传数据

**位置**: `ios/HealthSync/HealthSync/Modules/Sync/SyncHealthDataUseCase.swift:81`

代码注释 "Upload plaintext data (no encryption)"，加密模块存在但未被调用。
与 CLAUDE.md 文档中描述的 AES-256-GCM 端到端加密不符。

**修复方案**: 在上传前调用 `EncryptionService` 对数据加密。

---

## 中危 (Medium)

### 6. API Key 无频率限制

**位置**: `server/health-sync-server/src/middleware/apikey.middleware.ts`

Mac Mini 使用的 API Key 认证没有速率限制，可被暴力破解。

**修复方案**: 复用现有的 `express-rate-limit` 对 API Key 接口也加限制。

---

### 7. JWT 使用默认弱密钥

**位置**: `server/health-sync-server/src/config/`

默认值为 `'your-secret-key'` 和 `'your-refresh-secret'`，如果 `.env` 未配置则直接使用这些弱密钥。

**修复方案**: 强制校验环境变量，未配置时拒绝启动。

---

### 8. 无操作审计日志

**位置**: 全局

敏感操作（登录、数据上传、数据读取）没有审计记录，出现安全事件时无法溯源。

**修复方案**: 对关键操作写入审计日志，至少记录时间、用户、IP、操作类型。

---

## 低危 (Low)

### 9. 用户名明文存储在 UserDefaults

**位置**: `ios/HealthSync/HealthSync/Modules/Auth/LoginViewModel.swift:26`

用户名存储在 UserDefaults 而非 Keychain，存在隐私泄露风险。

**修复方案**: 迁移到 Keychain 存储。

---

## 已做得好的地方（参考）

- bcrypt 12 轮哈希密码
- iOS 访问令牌存储在 Keychain
- JWT 双令牌 + 自动刷新机制
- Zod 输入验证
- 速率限制 100次/15分钟（登录接口）
- 登录失败不泄露用户是否存在
