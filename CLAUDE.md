# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Architecture

This is a **Health Data Sync System** that securely transfers iPhone HealthKit data to a Tencent Cloud server, which then archives the data on a Mac Mini for AI analysis.

```
iPhone App (HealthSync) → 腾讯云服务器 (中转+7天缓冲) → Mac Mini (长期归档+小炎分析)
```

## Project Structure

The codebase consists of three independent components:

1. **Server** (`server/health-sync-server/`) - Node.js + TypeScript backend
2. **iOS App** (`ios/HealthSync/`) - Swift + SwiftUI
3. **Mac Mini Script** (`mac-mini/health-fetcher/`) - TypeScript

## Server (Node.js + TypeScript)

Location: `server/health-sync-server/`

### Commands
```bash
npm install                    # Install dependencies
cp .env.example .env          # Configure environment variables
npm run prisma:migrate        # Run database migrations
npm run dev                   # Start development server (watch mode)
npm run build                 # Build for production
npm start                     # Run production server
npm run prisma:studio         # Open Prisma Studio (database GUI)
npm run db:seed               # Seed database with initial users
```

### Architecture
- **Framework**: Express.js with TypeScript
- **Database**: Prisma ORM + SQLite
- **Authentication**: JWT tokens with refresh mechanism
- **Encryption**: AES-256-GCM (client-side, keys stored only on Mac Mini)
- **Security**: Helmet, rate limiting, bcrypt password hashing
- **Validation**: Zod schemas

### Key Files
- `src/server.ts` - Entry point, Express app setup
- `src/routes/` - API route definitions
- `prisma/schema.prisma` - Database schema
- `src/middleware/auth.ts` - JWT authentication middleware

### API Endpoints
```
POST /api/auth/login          - User login
POST /api/auth/refresh        - Refresh JWT token
POST /api/auth/logout         - Logout
GET  /api/auth/me             - Get current user

POST /api/health/upload       - Upload encrypted health data
GET  /api/health/status       - Get sync status
GET  /api/health/fetch        - Fetch data (Mac Mini)
DELETE /api/health/cleanup    - Cleanup old data (admin)
```

### Default Users (seeded)
- zhugong / zhugong123
- dage / dage123

## iOS App (Swift + SwiftUI)

Location: `ios/HealthSync/`

### Commands
```bash
# Open in Xcode
open ios/HealthSync/HealthSync.xcodeproj

# Build and run requires Xcode, must run on physical device (HealthKit limitation)
```

### Architecture
- **UI Framework**: SwiftUI
- **Health Access**: HealthKit framework
- **Encryption**: CryptoKit (AES-256-GCM)
- **Background Tasks**: BackgroundTasks framework for periodic sync
- **Secure Storage**: Keychain for credentials

### Project Structure
```
HealthSync/
├── App/                      # Application entry point
├── Core/
│   ├── DI/                   # Dependency injection container
│   └── Keychain/             # Keychain wrapper
├── Modules/
│   ├── Auth/                 # Login/register screens
│   ├── Health/               # HealthKit data fetching
│   ├── Encryption/           # AES encryption service
│   ├── Sync/                 # API sync logic
│   └── Settings/             # App settings
├── Shared/UI/Themes/          # UI theming (dark mode)
└── Main/                     # Main dashboard view
```

### Configuration
Server URL is configured in `App/DI/AppContainer.swift`:
```swift
enum Config {
    static var serverURL: String = "https://your-server.com"
}
```

### Health Data Types Supported
- Sleep analysis (`HKCategoryType.sleepAnalysis`)
- Heart rate (`HKQuantityType.heartRate`)
- Resting heart rate (`HKQuantityType.restingHeartRate`)
- HRV (`HKQuantityType.heartRateVariabilitySDNN`)
- Steps (`HKQuantityType.stepCount`)
- Workouts (`HKObjectType.workoutType()`)
- Blood oxygen (`HKQuantityType.oxygenSaturation`)
- Body mass (`HKQuantityType.bodyMass`)
- Mindfulness (`HKCategoryType.mindfulSession`)

## Mac Mini Script (TypeScript)

Location: `mac-mini/health-fetcher/`

### Commands
```bash
npm install                    # Install dependencies
cp .env.example .env          # Configure environment
npm run build                 # Build TypeScript
npm start                     # Run fetcher (all data)
npm start today               # Run fetcher (today's data only)
npm run dev                   # Development mode
```

### Configuration
Keys are stored in `~/.openclaw/keys/health_sync.json`:
```json
{
  "zhugong": "64-char-hex-key",
  "dage": "64-char-hex-key"
}
```

Environment variables in `.env`:
```bash
SERVER_URL=https://your-server.com
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
WORKSPACE_PATH=~/.openclaw/workspace/health
```

### Data Storage
Decrypted data stored as daily JSON files:
```
~/.openclaw/workspace/health/
├── zhugong/
│   ├── 2026-03-26.json
│   └── 2026-03-27.json
└── dage/
    └── ...
```

### Cron Schedule
Recommended daily execution at 23:00:
```bash
0 23 * * * cd ~/.openclaw/health-fetcher && npm start
```

## Security Architecture

1. **End-to-end encryption**: Health data is encrypted on iOS device using AES-256-GCM before upload
2. **Encryption keys**: NEVER stored on server - only on Mac Mini (`~/.openclaw/keys/`)
3. **Transport security**: HTTPS required for all API communication
4. **Authentication**: JWT tokens with automatic refresh
5. **Data retention**: Server auto-deletes data after 7 days
6. **User isolation**: Complete data separation between users

## Generating Encryption Keys

Generate 32-byte (64 hex char) keys:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Key must be synchronized between iOS app and Mac Mini script, but NEVER on the server.
