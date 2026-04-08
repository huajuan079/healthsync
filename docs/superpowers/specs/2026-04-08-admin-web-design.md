# HealthSync Admin Web 后台界面设计文档

**日期：** 2026-04-08  
**状态：** 已批准，待实现

---

## 背景

现有 `/healthsync/api/health/web/uploads` 页面为服务端拼接 HTML 字符串，无鉴权、无分页、无排序，数据预览截断在 200 字符。目标是将其升级为标准后台管理界面。

---

## 技术选型

- **前端**：Vue 3 + Vue Router + ElementPlus，全部通过 CDN 引入，零构建步骤
- **后端**：Express 新增 JSON API 路由，独立 admin session cookie 鉴权
- **鉴权**：`.env` 增加 `ADMIN_WEB_PASSWORD`，登录后服务端 `Set-Cookie: admin_session=<signed-token>; HttpOnly; SameSite=Strict`
- **托管**：`server/health-sync-server/public/admin/index.html`，Express `express.static` 托管

---

## 目录结构变更

```
server/health-sync-server/
├── public/
│   └── admin/
│       └── index.html                    # 新增：Vue 单页 Shell
├── src/
│   ├── routes/
│   │   ├── admin-web.routes.ts           # 新增：Web Admin JSON API 路由
│   │   └── index.ts                      # 修改：挂载新路由
│   └── controllers/
│       └── admin-web.controller.ts       # 新增：Admin Web 控制器
```

现有 `/health/web/uploads` 和 `/health/web/upload/:id` **保留不动**，避免破坏现有书签。

---

## API 端点

所有端点挂载在 `/health/web/api/`，除 `/login` 外均需要 admin session cookie。

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/health/web/api/login` | 验证密码，Set-Cookie admin_session |
| `POST` | `/health/web/api/logout` | 清除 Cookie |
| `GET` | `/health/web/api/users` | 用户列表 + 统计 |
| `GET` | `/health/web/api/users/:id/uploads` | 单用户上传记录（分页+排序） |
| `GET` | `/health/web/api/uploads/:id` | 单条上传详情 + 文件内容 |

### `/users` 响应

```json
{
  "users": [
    {
      "id": "uuid",
      "username": "zhugong",
      "totalUploads": 42,
      "lastSyncAt": "2026-04-07T23:00:00Z",
      "isActive": true
    }
  ]
}
```

### `/users/:id/uploads` 查询参数

- `page`（默认 1）
- `pageSize`（默认 20，固定）
- `sortBy`（默认 `createdAt`，可选：`date`、`recordCount`、`fileSize`、`createdAt`）
- `sortOrder`（默认 `desc`，可选：`asc`）

响应：
```json
{
  "total": 85,
  "page": 1,
  "pageSize": 20,
  "data": [
    {
      "id": "uuid",
      "date": "2026-04-07",
      "batchIndex": 0,
      "batchTotal": 1,
      "recordCount": 120,
      "fileSize": 4096,
      "status": "completed",
      "createdAt": "2026-04-07T23:05:00Z"
    }
  ]
}
```

### `/uploads/:id` 额外字段

基础字段之外多返回 `fileContent`：文件存在则为完整 JSON 字符串，不存在则 `null`。

---

## 前端页面设计

**路由模式**：Vue Router Hash 模式（无需服务器额外配置）

| 路由 | 页面 |
|------|------|
| `/#/login` | 登录页 |
| `/#/users` | 用户列表页 |
| `/#/users/:id` | 用户上传列表页 |
| `/#/uploads/:id` | 上传详情页 |

### 登录页 `/#/login`

- 居中 `ElCard`，密码输入框 + 登录按钮
- 错误提示：`ElMessage.error()`
- 登录成功：跳转 `/#/users`
- 已登录时访问此路由自动跳转 `/#/users`

### 用户列表页 `/#/users`

- 顶部固定导航栏：标题 "HealthSync Admin" + 退出按钮
- 统计卡片行：用户总数、总上传批次（来自 `/users` 接口聚合）
- `ElTable`：用户名、总上传数、最后同步时间、状态 `ElTag`（active/inactive）、操作列
- 点击行或操作列按钮跳转 `/#/users/:id`

### 用户上传列表页 `/#/users/:id`

- `ElBreadcrumb`：首页 > 用户名
- `ElTable`：日期、批次（`batchIndex+1/batchTotal`）、记录数、文件大小、状态 Tag、上传时间、操作
- 表头点击排序（`sort-change` 事件 → 更新 `sortBy`/`sortOrder` → 重新请求）
- 底部 `ElPagination`：`layout="total, prev, pager, next"`，每页固定 20 条
- 点击操作列按钮跳转 `/#/uploads/:id`

### 上传详情页 `/#/uploads/:id`

- `ElBreadcrumb`：首页 > 用户名 > 详情
- 基础信息：`ElDescriptions`（`border`，2 列）展示所有字段（ID、用户、日期、批次、记录数、文件大小、状态、校验和、上传时间）
- 文件内容卡片：标题 + "展开/收起" 按钮（`ElCollapse`），展开后 `<pre>` 展示 `JSON.stringify(parsed, null, 2)`，背景 `#1e1e1e`，白色字体，`monospace`，`max-height: 600px; overflow-y: auto`
- `fileContent` 为 `null` 时显示灰色提示文字："文件已归档或不存在"

---

## 整体风格

- ElementPlus 默认主题（蓝色 `#409EFF`）
- 页面最大宽度 1200px，水平居中，左右 24px padding
- 顶部固定导航栏（`position: fixed`），高 60px，内容区 `padding-top: 80px`
- 状态颜色：`completed` → `success`，`pending` → `warning`，`failed` → `danger`

---

## 鉴权实现细节

- `ADMIN_WEB_PASSWORD` 从 `process.env` 读取，启动时验证存在性
- Session token：`crypto.createHmac('sha256', secret).update(timestamp).digest('hex')` + 时间戳，拼接后 base64 存入 cookie
- Cookie 有效期：7 天
- 中间件 `requireAdminSession`：解析 cookie → 验签 → 检查过期 → 通过或 401
- 登出：`Set-Cookie: admin_session=; Max-Age=0`

---

## 不在本次范围内

- 数据修改/删除操作（只读界面）
- 多管理员账号
- 操作日志
- 数据导出
