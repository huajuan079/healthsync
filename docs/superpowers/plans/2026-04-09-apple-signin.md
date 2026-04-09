# Sign in with Apple Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有用户名/密码登录基础上接入 Sign in with Apple，允许新用户自助注册。

**Architecture:** iOS 使用 AuthenticationServices 框架触发苹果授权，获取 identityToken 后发给服务端 POST /api/auth/apple，服务端用 apple-signin-auth 验证 token 并 find-or-create 用户，返回 JWT。加密密钥管理后期单独处理，本期 Apple 用户暂无加密密钥。

**Tech Stack:** Server: Node.js + TypeScript + Prisma + apple-signin-auth. iOS: Swift + SwiftUI + AuthenticationServices（内置框架）.

---

## 文件变更清单

**Server:**
- Modify: `server/health-sync-server/prisma/schema.prisma` — `password` 改可选，新增 `appleUserId`
- Modify: `server/health-sync-server/src/config/index.ts` — 新增 `apple.clientId`
- Modify: `server/health-sync-server/src/types/index.ts` — 新增 `AppleLoginRequest`
- Modify: `server/health-sync-server/src/services/auth.service.ts` — 新增 `appleLogin()`，修复 null password 判断
- Modify: `server/health-sync-server/src/controllers/auth.controller.ts` — 新增 `appleLogin()` handler
- Modify: `server/health-sync-server/src/routes/auth.routes.ts` — 新增 `POST /apple`
- Modify: `server/health-sync-server/.env.example` — 新增 `APPLE_CLIENT_ID`

**iOS:**
- Modify: `ios/HealthSync/HealthSync/Modules/Network/Data/Services/APIService.swift` — 新增 `.appleLogin` endpoint + `AppleLoginRequest` 模型
- Modify: `ios/HealthSync/HealthSync/Modules/Auth/Data/Repositories/AuthRepository.swift` — 新增 `appleLogin()` 方法
- Create: `ios/HealthSync/HealthSync/Modules/Auth/Domain/UseCases/AppleSignInUseCase.swift` — Apple 授权 use case
- Modify: `ios/HealthSync/HealthSync/Core/DI/AppContainer.swift` — 注册 `appleSignInUseCase`
- Modify: `ios/HealthSync/HealthSync/Modules/Auth/Presentation/ViewModels/LoginViewModel.swift` — 新增 `handleAppleSignIn()`
- Modify: `ios/HealthSync/HealthSync/Modules/Auth/Presentation/Views/LoginView.swift` — 新增 Apple 按钮

---

## Task 1: Server — Prisma Schema 变更 + Migration

**Files:**
- Modify: `server/health-sync-server/prisma/schema.prisma`
- Modify: `server/health-sync-server/src/services/auth.service.ts` (第 31-32 行，修复 null password)

- [ ] **Step 1: 修改 prisma/schema.prisma**

将 `password String` 改为可选，并新增 `appleUserId` 字段：

```prisma
model User {
  id          String   @id @default(uuid())
  username    String   @unique
  password    String?
  appleUserId String?  @unique
  role        String   @default("user")
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  sessions   Session[]
  uploads    Upload[]
  syncStatus SyncStatus[]
}
```

- [ ] **Step 2: 运行 migration**

```bash
cd server/health-sync-server
npm run prisma:migrate
# 提示输入 migration 名称时输入：add_apple_signin
```

期望输出：
```
✔ Generated Prisma Client
The following migration(s) have been applied:
  migrations/YYYYMMDDHHMMSS_add_apple_signin/migration.sql
```

- [ ] **Step 3: 修复 auth.service.ts 中的 null password 判断**

在 `auth.service.ts` 第 28 行 `if (!user.isActive)` 检查之后，`bcrypt.compare` 之前，加 null password 检查（第 30-35 行区域）：

```typescript
    if (!user.isActive) {
      throw new Error('Account is disabled');
    }

    if (!user.password) {
      throw new Error('This account uses Apple Sign In. Please use Sign in with Apple.');
    }

    const isValid = await bcrypt.compare(password, user.password);
```

- [ ] **Step 4: Commit**

```bash
cd server/health-sync-server
git add prisma/schema.prisma prisma/migrations/ src/services/auth.service.ts
git commit -m "feat(server): add appleUserId to User schema, handle null password"
```

---

## Task 2: Server — 安装依赖 + 新增类型 + Config

**Files:**
- Modify: `server/health-sync-server/src/types/index.ts`
- Modify: `server/health-sync-server/src/config/index.ts`
- Modify: `server/health-sync-server/.env.example`

- [ ] **Step 1: 安装 apple-signin-auth**

```bash
cd server/health-sync-server
npm install apple-signin-auth
```

期望输出：包含 `added 1 package` 或类似的安装成功信息。

- [ ] **Step 2: 在 types/index.ts 末尾新增 AppleLoginRequest 类型**

在文件末尾（`ApiError` 接口之后）追加：

```typescript
export interface AppleLoginRequest {
  identityToken: string;
  userIdentifier: string;
  email?: string;
  fullName?: string;
}
```

- [ ] **Step 3: 在 config/index.ts 中新增 apple 配置**

在 `storage` 字段之后，`} as const` 之前，追加：

```typescript
  apple: {
    clientId: process.env.APPLE_CLIENT_ID || '',
  },
```

完整的 `config` 对象末尾应为：

```typescript
  storage: {
    basePath: './storage/health_data',
  },

  apple: {
    clientId: process.env.APPLE_CLIENT_ID || '',
  },
} as const;
```

- [ ] **Step 4: 更新 .env.example**

在文件末尾追加：

```
# Sign in with Apple - set to your iOS App Bundle ID
APPLE_CLIENT_ID=com.yourname.healthsync
```

- [ ] **Step 5: Commit**

```bash
cd server/health-sync-server
git add package.json package-lock.json src/types/index.ts src/config/index.ts .env.example
git commit -m "feat(server): add apple-signin-auth dependency and config"
```

---

## Task 3: Server — appleLogin Service 方法

**Files:**
- Modify: `server/health-sync-server/src/services/auth.service.ts`

- [ ] **Step 1: 在 auth.service.ts 顶部修改 import**

将现有的 types import：
```typescript
import type { LoginRequest, LoginResponse, RefreshTokenRequest } from '../types';
```
改为（加入 `AppleLoginRequest`）：
```typescript
import type { LoginRequest, LoginResponse, RefreshTokenRequest, AppleLoginRequest } from '../types';
```

然后在该行之后追加两行：
```typescript
import appleSignin from 'apple-signin-auth';
import { config } from '../config';
```

- [ ] **Step 2: 在 AuthService class 中新增 appleLogin 方法**

在 `cleanupExpiredSessions` 方法之后（class 末尾 `}` 之前）添加：

```typescript
  /**
   * Authenticate or register user via Apple Sign In
   */
  async appleLogin(request: AppleLoginRequest): Promise<LoginResponse> {
    const { identityToken, email, fullName } = request;

    // Verify the identity token via Apple's public JWKS
    let appleUserId: string;
    try {
      const payload = await appleSignin.verifyIdToken(identityToken, {
        audience: config.apple.clientId,
        ignoreExpiration: false,
      });
      appleUserId = payload.sub;
    } catch (err) {
      logger.warn('Apple identity token verification failed', err);
      throw new Error('Invalid Apple identity token');
    }

    // Find or create user
    let user = await prisma.user.findUnique({ where: { appleUserId } });

    if (!user) {
      const username = `apple_${appleUserId.substring(0, 8).toLowerCase()}`;
      user = await prisma.user.create({
        data: {
          username,
          password: null,
          appleUserId,
          role: 'user',
        },
      });
      logger.info(`Created Apple user: ${username}`);
    }

    if (!user.isActive) {
      throw new Error('Account is disabled');
    }

    const tokenPayload = {
      userId: user.id,
      username: user.username,
      role: user.role,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await prisma.session.deleteMany({ where: { userId: user.id } });
    await prisma.session.create({
      data: { userId: user.id, refreshToken, expiresAt },
    });

    logger.info(`Apple user logged in: ${user.username}`);

    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: 3600,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
      },
    };
  }
```

- [ ] **Step 3: 验证 TypeScript 编译无报错**

```bash
cd server/health-sync-server
npm run build
```

期望：编译成功，无错误。如有类型错误根据提示修复。

- [ ] **Step 4: Commit**

```bash
cd server/health-sync-server
git add src/services/auth.service.ts
git commit -m "feat(server): implement appleLogin service method"
```

---

## Task 4: Server — Controller + Route

**Files:**
- Modify: `server/health-sync-server/src/controllers/auth.controller.ts`
- Modify: `server/health-sync-server/src/routes/auth.routes.ts`

- [ ] **Step 1: 在 auth.controller.ts 中新增 appleLoginSchema 和 handler**

在现有 `refreshSchema` 定义之后，`export class AuthController` 之前，新增 schema：

```typescript
const appleLoginSchema = z.object({
  identityToken: z.string().min(1),
  userIdentifier: z.string().min(1),
  email: z.string().email().optional(),
  fullName: z.string().optional(),
});
```

在 `AuthController` class 的 `me` 方法之后，class 末尾 `}` 之前，新增：

```typescript
  /**
   * POST /auth/apple
   */
  async appleLogin(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const body = appleLoginSchema.parse(req.body);
      const result = await authService.appleLogin(body);
      res.json(result);
    } catch (error) {
      if (error instanceof Error) {
        res.status(401).json({ error: error.message });
      } else {
        next(error);
      }
    }
  }
```

- [ ] **Step 2: 在 auth.routes.ts 中新增路由**

在 `router.get('/me', ...)` 之后，`export { router as authRoutes }` 之前，新增：

```typescript
/**
 * POST /auth/apple
 * Sign in or register with Apple ID
 */
router.post('/apple', authController.appleLogin.bind(authController));
```

- [ ] **Step 3: 启动 dev server，手动验证路由存在**

```bash
cd server/health-sync-server
npm run dev
```

在另一个终端：

```bash
curl -s -X POST http://localhost:3000/api/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"identityToken":"invalid","userIdentifier":"test"}' | jq .
```

期望输出（token 无效，但路由正常响应）：
```json
{ "error": "Invalid Apple identity token" }
```

如果返回 404，说明路由没注册正确，检查 `auth.routes.ts`。

- [ ] **Step 4: Commit**

```bash
cd server/health-sync-server
git add src/controllers/auth.controller.ts src/routes/auth.routes.ts
git commit -m "feat(server): add POST /api/auth/apple endpoint"
```

---

## Task 5: iOS — 新增 Endpoint case + AppleLoginRequest 模型

**Files:**
- Modify: `ios/HealthSync/HealthSync/Modules/Network/Data/Services/APIService.swift`

- [ ] **Step 1: 在 `Endpoint` enum 中新增 appleLogin case**

在 `case healthFetch` 之后，`static func ==` 之前，新增：

```swift
    case appleLogin(identityToken: String, userIdentifier: String, email: String?, fullName: String?)
```

- [ ] **Step 2: 更新 `Endpoint` 的 `==` 实现**

在 `case (.healthFetch, .healthFetch):` 之后，`return true` 之前，补充：

```swift
        case (.appleLogin, .appleLogin):
```

完整的 switch case 应为：

```swift
        case (.login, .login),
             (.refreshToken, .refreshToken),
             (.healthUpload, .healthUpload),
             (.healthStatus, .healthStatus),
             (.healthFetch, .healthFetch),
             (.appleLogin, .appleLogin):
            return true
```

- [ ] **Step 3: 更新 `var path: String`**

在 `case .healthFetch:` 之后，closing `}` 之前，新增：

```swift
        case .appleLogin:
            return "/api/auth/apple"
```

- [ ] **Step 4: 更新 `var method: String`**

将现有：

```swift
        case .login, .refreshToken, .healthUpload:
            return "POST"
```

改为：

```swift
        case .login, .refreshToken, .healthUpload, .appleLogin:
            return "POST"
```

- [ ] **Step 5: 在 `buildRequest` 中处理 appleLogin body**

在 `case .healthFetch` 处理块之后，`default: break` 之前，新增：

```swift
        case .appleLogin(let identityToken, let userIdentifier, let email, let fullName):
            let body = AppleLoginRequest(
                identityToken: identityToken,
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )
            request.httpBody = try JSONEncoder().encode(body)
```

- [ ] **Step 6: 在 401 retry 排除列表中加入 appleLogin**

找到现有的：

```swift
           endpoint != .login(username: "", password: ""),
           endpoint != .refreshToken(token: "") {
```

改为：

```swift
           endpoint != .login(username: "", password: ""),
           endpoint != .refreshToken(token: ""),
           endpoint != .appleLogin(identityToken: "", userIdentifier: "", email: nil, fullName: nil) {
```

- [ ] **Step 7: 在文件末尾新增 AppleLoginRequest 结构体**

在 `HealthDataBatch` struct 之后，追加：

```swift
struct AppleLoginRequest: Codable {
    let identityToken: String
    let userIdentifier: String
    let email: String?
    let fullName: String?
}
```

- [ ] **Step 8: 在 Xcode 中验证编译通过**

打开 Xcode，⌘+B 编译。期望：无编译错误。

- [ ] **Step 9: Commit**

```bash
git add ios/HealthSync/HealthSync/Modules/Network/Data/Services/APIService.swift
git commit -m "feat(ios): add appleLogin endpoint and AppleLoginRequest model"
```

---

## Task 6: iOS — 更新 AuthRepository

**Files:**
- Modify: `ios/HealthSync/HealthSync/Modules/Auth/Data/Repositories/AuthRepository.swift`

- [ ] **Step 1: 在 `AuthRepositoryProtocol` 中新增方法签名**

在 `func logout() throws` 之后，`}` 之前，新增：

```swift
    func appleLogin(identityToken: String, userIdentifier: String, email: String?, fullName: String?) async throws -> LoginResponse
```

- [ ] **Step 2: 在 `AuthRepository` class 中实现 appleLogin**

在 `func logout()` 方法之后，class 末尾 `}` 之前，新增：

```swift
    func appleLogin(identityToken: String, userIdentifier: String, email: String?, fullName: String?) async throws -> LoginResponse {
        let response: LoginResponse = try await apiService.request(
            .appleLogin(identityToken: identityToken, userIdentifier: userIdentifier, email: email, fullName: fullName)
        )
        try keychainManager.set(key: .accessToken, value: response.accessToken)
        try keychainManager.set(key: .refreshToken, value: response.refreshToken)
        if let api = apiService as? APIService { api.setAuthToken(response.accessToken) }
        return response
    }
```

- [ ] **Step 3: 在 Xcode 中验证编译通过（⌘+B）**

- [ ] **Step 4: Commit**

```bash
git add ios/HealthSync/HealthSync/Modules/Auth/Data/Repositories/AuthRepository.swift
git commit -m "feat(ios): implement appleLogin in AuthRepository"
```

---

## Task 7: iOS — 创建 AppleSignInUseCase

**Files:**
- Create: `ios/HealthSync/HealthSync/Modules/Auth/Domain/UseCases/AppleSignInUseCase.swift`

- [ ] **Step 1: 创建文件**

新建文件 `ios/HealthSync/HealthSync/Modules/Auth/Domain/UseCases/AppleSignInUseCase.swift`，内容：

```swift
import Foundation

protocol AppleSignInUseCaseProtocol {
    func execute(identityToken: String, userIdentifier: String, email: String?, fullName: String?) async throws -> String
}

final class AppleSignInUseCase: AppleSignInUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    /// Returns the username assigned by the server (e.g. "apple_xxxxxxxx")
    func execute(identityToken: String, userIdentifier: String, email: String?, fullName: String?) async throws -> String {
        let response = try await authRepository.appleLogin(
            identityToken: identityToken,
            userIdentifier: userIdentifier,
            email: email,
            fullName: fullName
        )
        return response.user.username
    }
}

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Apple 登录凭证无效"
        case .missingToken: return "未能获取 Apple 授权 token"
        }
    }
}
```

- [ ] **Step 2: 在 Xcode 中将文件加入 Target**

在 Xcode 中右键 `UseCases` 文件夹 → Add Files，选择新文件，确保勾选 HealthSync target。

- [ ] **Step 3: 验证编译（⌘+B）**

- [ ] **Step 4: Commit**

```bash
git add ios/HealthSync/HealthSync/Modules/Auth/Domain/UseCases/AppleSignInUseCase.swift
git commit -m "feat(ios): add AppleSignInUseCase"
```

---

## Task 8: iOS — 更新 AppContainer + LoginViewModel

**Files:**
- Modify: `ios/HealthSync/HealthSync/Core/DI/AppContainer.swift`
- Modify: `ios/HealthSync/HealthSync/Modules/Auth/Presentation/ViewModels/LoginViewModel.swift`

- [ ] **Step 1: 在 AppContainer 中注册 appleSignInUseCase**

在 `lazy var loginUseCase = ...` 之后，新增：

```swift
    lazy var appleSignInUseCase: AppleSignInUseCaseProtocol = AppleSignInUseCase(authRepository: authRepository)
```

- [ ] **Step 2: 在 LoginViewModel.swift 顶部添加 import**

在 `import Foundation` 之后，新增：

```swift
import AuthenticationServices
```

- [ ] **Step 3: 更新 LoginViewModel 的 init，接收 appleSignInUseCase**

将现有：

```swift
    private let loginUseCase: LoginUseCaseProtocol

    init(loginUseCase: LoginUseCaseProtocol) {
        self.loginUseCase = loginUseCase
    }
```

改为：

```swift
    private let loginUseCase: LoginUseCaseProtocol
    private let appleSignInUseCase: AppleSignInUseCaseProtocol

    init(loginUseCase: LoginUseCaseProtocol, appleSignInUseCase: AppleSignInUseCaseProtocol) {
        self.loginUseCase = loginUseCase
        self.appleSignInUseCase = appleSignInUseCase
    }
```

- [ ] **Step 4: 在 `warmUpConnection()` 之后新增 handleAppleSignIn 方法**

```swift
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task { await performAppleSignIn(authorization: authorization) }
        case .failure(let error):
            errorMessage = LoginViewModel.friendlyMessage(for: error)
        }
    }

    private func performAppleSignIn(authorization: ASAuthorization) async {
        isLoading = true
        do {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                throw AppleSignInError.missingToken
            }
            let userIdentifier = credential.user
            let email = credential.email
            let fullName: String? = {
                let parts = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }()

            let username = try await appleSignInUseCase.execute(
                identityToken: identityToken,
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )
            UserDefaultsManager.shared.username = username
            print("[LoginViewModel] Apple user logged in: \(username)")
            isLoading = false
            NotificationCenter.default.post(name: .didLogin, object: nil)
        } catch {
            isLoading = false
            errorMessage = LoginViewModel.friendlyMessage(for: error)
        }
    }
```

- [ ] **Step 5: 验证编译（⌘+B）**

- [ ] **Step 6: Commit**

```bash
git add ios/HealthSync/HealthSync/Core/DI/AppContainer.swift \
        ios/HealthSync/HealthSync/Modules/Auth/Presentation/ViewModels/LoginViewModel.swift
git commit -m "feat(ios): wire appleSignInUseCase into AppContainer and LoginViewModel"
```

---

## Task 9: iOS — 更新 LoginView 添加 Apple 登录按钮

**Files:**
- Modify: `ios/HealthSync/HealthSync/Modules/Auth/Presentation/Views/LoginView.swift`

- [ ] **Step 1: 在 LoginView.swift 顶部添加 import**

在 `import SwiftUI` 之后，新增：

```swift
import AuthenticationServices
```

- [ ] **Step 2: 更新 LoginView 的 init，传入 appleSignInUseCase**

将现有：

```swift
    init(container: AppContainer) {
        self._viewModel = StateObject(wrappedValue: LoginViewModel(loginUseCase: container.loginUseCase))
    }
```

改为：

```swift
    init(container: AppContainer) {
        self._viewModel = StateObject(wrappedValue: LoginViewModel(
            loginUseCase: container.loginUseCase,
            appleSignInUseCase: container.appleSignInUseCase
        ))
    }
```

- [ ] **Step 3: 在 LoginFormView 中加入分隔线和 Apple 按钮**

将 `LoginFormView.body` 中最后一个 `Button`（登录按钮）之后，`}` 之前，新增：

```swift
            HStack {
                Rectangle().frame(height: 1).foregroundColor(.tertiaryBackground)
                Text("或").font(.caption).foregroundColor(.tertiaryText).padding(.horizontal, 8)
                Rectangle().frame(height: 1).foregroundColor(.tertiaryBackground)
            }
            .padding(.top, 4)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                viewModel.handleAppleSignIn(result: result)
            }
            .frame(height: 50)
            .signInWithAppleButtonStyle(.black)
            .cornerRadius(10)
            .disabled(viewModel.isLoading)
```

- [ ] **Step 4: 验证编译（⌘+B）**

- [ ] **Step 5: 验证 UI 在 Preview 中正确显示**

在 Xcode 预览中确认：
- 原有用户名/密码表单完整显示
- "或" 分隔线在登录按钮下方
- 黑色的 "Sign in with Apple" 按钮在分隔线下方

- [ ] **Step 6: Commit**

```bash
git add ios/HealthSync/HealthSync/Modules/Auth/Presentation/Views/LoginView.swift
git commit -m "feat(ios): add Sign in with Apple button to LoginView"
```

---

## Task 10: 部署服务端 + 端对端验证

**注意：** 这一步需要你在 Xcode 里配置好 Sign in with Apple Capability，并且在 developer.apple.com 上已完成 App ID 配置。

- [ ] **Step 1: 在服务端 .env 中配置 APPLE_CLIENT_ID**

编辑 `server/health-sync-server/.env`，添加：

```
APPLE_CLIENT_ID=com.yourname.healthsync
```

将 `com.yourname.healthsync` 替换为你在 developer.apple.com 配置的实际 Bundle ID。

- [ ] **Step 2: 在 Xcode 中添加 Sign in with Apple Capability**

1. 打开 Xcode → HealthSync target → Signing & Capabilities
2. 点击 `+` → 搜索 "Sign in with Apple" → 双击添加
3. 确认 Bundle Identifier 与 developer.apple.com 上的一致

- [ ] **Step 3: 重新部署服务端**

根据内存记录，服务端部署在 `markmager.cc/healthsync`，使用 Docker。

```bash
cd server/health-sync-server
npm run build
# 然后按照你的 Docker 部署流程重新部署（更新镜像）
```

确保生产环境 `.env` 里也有 `APPLE_CLIENT_ID`。

- [ ] **Step 4: 在真机上运行 app 并测试 Sign in with Apple**

在真机（不能用模拟器测试 Sign in with Apple）上：
1. 运行 app，确认 Login 界面显示 Apple 按钮
2. 点击 "Sign in with Apple"，系统弹出授权界面
3. 完成授权
4. 期望：成功登录，进入主界面
5. 验证：服务端日志显示 `Created Apple user: apple_xxxxxxxx` 和 `Apple user logged in: apple_xxxxxxxx`

- [ ] **Step 5: Final Commit**

```bash
git add server/health-sync-server/.env.example
git commit -m "feat: complete Sign in with Apple integration"
```
