# Build stage
FROM node:18-alpine AS builder
WORKDIR /app

# Only copy package files needed for build
COPY package.json ./

# Install dependencies
RUN npm install --no-package-lock

# Copy only the TypeScript source and config
COPY tsconfig.json ./
COPY src ./src

# Build TypeScript code
RUN npm run build

# Clean build stage
FROM node:18-alpine AS deps
WORKDIR /app
COPY package.json ./

# Install only production dependencies with minimal extras
RUN npm install --omit=dev --no-package-lock --no-audit --no-fund

# Final stage
FROM node:18-alpine
WORKDIR /app

# Copy only the built JavaScript files and production dependencies
COPY --from=builder /app/dist ./dist
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./

# Set environment variables
ENV NODE_ENV=production
ENV TEMPORAL_ADDRESS=temporal:7233
ENV TEMPORAL_NAMESPACE=default

# Start the worker
CMD ["node", "dist/worker.js"] 