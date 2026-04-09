# Sign in with Apple — 设计文档

**日期：** 2026-04-09  
**状态：** 已批准

---

## 目标

在现有用户名/密码登录基础上，新增 Sign in with Apple，允许新用户通过 Apple ID 自助注册并登录。加密密钥管理问题后期单独处理，本期不涉及。

---

## 前置条件（手动操作，代码前必须完成）

1. 登录 [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Identifiers
2. 新建或编辑 App ID，勾选 **Sign in with Apple** capability
3. 记录 **Bundle ID**（如 `com.yourname.healthsync`）和 **Team ID**
4. 在 Xcode 项目 → Signing & Capabilities → 添加 **Sign in with Apple**
5. 在服务端 `.env` 里配置 `APPLE_CLIENT_ID=<你的 Bundle ID>`

---

## 整体数据流

```
用户点击 "Sign in with Apple"
    ↓
iOS ASAuthorizationAppleIDProvider（系统弹窗授权）
    ↓
Apple 返回: { userIdentifier, identityToken (JWT), email?, fullName? }
    ↓
iOS POST /api/auth/apple { identityToken, userIdentifier, email?, fullName? }
    ↓
Server 用 apple-signin-auth 库验证 identityToken
（通过 Apple 公钥 JWKS，无需 .p8 私钥）
    ↓
查 DB: User.appleUserId == userIdentifier?
    ├─ 找到 → 直接返回 JWT（登录）
    └─ 没找到 → 创建新用户 → 返回 JWT（注册）
    ↓
iOS 存 Keychain → 发 .didLogin 通知 → 进入主界面
```

---

## 服务端设计

### 数据库变更（prisma/schema.prisma）

```prisma
model User {
  id          String   @id @default(uuid())
  username    String   @unique
  password    String?          // 改为可选（Apple 用户无密码）
  appleUserId String?  @unique // 新增
  role        String   @default("user")
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  sessions   Session[]
  uploads    Upload[]
  syncStatus SyncStatus[]
}
```

### 新增依赖

```bash
npm install apple-signin-auth
```

### 新增环境变量

```
APPLE_CLIENT_ID=com.yourname.healthsync
```

### 新增端点

`POST /api/auth/apple`

**Request：**
```json
{
  "identityToken": "<Apple JWT>",
  "userIdentifier": "<stable Apple user ID>",
  "email": "user@example.com",       // 可选，仅首次授权时提供
  "fullName": "张三"                   // 可选，仅首次授权时提供
}
```

**Response（成功，与现有 login 一致）：**
```json
{
  "accessToken": "...",
  "refreshToken": "..."
}
```

**Response（失败）：**
```json
{ "error": "Invalid Apple identity token" }
```

### 新用户自动创建规则

- `username` = `apple_` + `userIdentifier` 前8位（小写）
- `password` = null
- `appleUserId` = Apple 返回的 `userIdentifier`
- `role` = `"user"`（默认）

### 修改文件清单

| 文件 | 改动 |
|------|------|
| `prisma/schema.prisma` | `password` 改可选，新增 `appleUserId` 字段 |
| `src/services/auth.service.ts` | 新增 `appleLogin()` 方法 |
| `src/controllers/auth.controller.ts` | 新增 `appleLogin()` handler |
| `src/routes/auth.routes.ts` | 新增 `POST /apple` 路由 |
| `.env.example` | 新增 `APPLE_CLIENT_ID` 示例 |

---

## iOS 设计

### UI 变更（LoginView）

在现有登录表单下方加分隔线和 Apple 按钮：

```
[用户名输入框]
[密码输入框]
[登录按钮]

─────── 或 ───────

[  Sign in with Apple  ]
```

使用 SwiftUI 原生 `SignInWithAppleButton`（`AuthenticationServices`，iOS 14+，内置无需安装）。

### 新增文件

| 文件 | 职责 |
|------|------|
| `Modules/Auth/Domain/UseCases/AppleSignInUseCase.swift` | 封装 ASAuthorizationAppleIDProvider 授权逻辑，返回 token 给 ViewModel |

### 修改文件清单

| 文件 | 改动 |
|------|------|
| `AuthRepository.swift` | 新增 `appleLogin(identityToken:userIdentifier:email:fullName:)` |
| `AuthRepositoryProtocol`（在 AuthRepository.swift 中） | 新增方法签名 |
| `LoginViewModel.swift` | 新增 `handleAppleSignIn(result:)` 方法 |
| `LoginView.swift` | 加分隔线 + `SignInWithAppleButton` |
| `APIEndpoint`（所在文件） | 新增 `.appleLogin` case |

### 登录成功后处理

- `UserDefaultsManager.shared.username` 设为服务端返回（或本地构造）的 `apple_xxxx`
- 存 Keychain（accessToken / refreshToken）
- 发 `.didLogin` 通知
- 加密密钥问题后期处理，本期 Apple 用户上传数据时会因无密钥而失败，这是已知限制

---

## 安全说明

- 服务端验证 `identityToken`（Apple 签发的 JWT），通过 Apple 公开的 JWKS 端点验证签名
- 不信任客户端传来的 `userIdentifier`，以 token 验证结果中的 `sub` 为准
- Apple 用户无密码，密码字段为 null，现有密码登录逻辑不受影响

---

## 已知限制（本期不处理）

- Apple 用户暂无加密密钥，健康数据上传会失败（后期专项处理）
- `email` 和 `fullName` 仅在用户首次授权时由 Apple 提供，后续登录不再包含
