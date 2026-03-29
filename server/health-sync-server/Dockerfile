# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

# Copy prisma schema and generate client before tsc (for correct types)
COPY prisma ./prisma
RUN npx prisma generate

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine
WORKDIR /app

# Prisma requires openssl
RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci --omit=dev

# Copy prisma schema and generate client
COPY prisma ./prisma
RUN npx prisma generate

# Copy compiled JS from builder
COPY --from=builder /app/dist ./dist

# Create persistent data directories
RUN mkdir -p /app/data /app/storage/health_data

EXPOSE 3000

# Push schema to DB (creates if not exists) then start server
CMD ["sh", "-c", "npx prisma db push && node dist/server.js"]
