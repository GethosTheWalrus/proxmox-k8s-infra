FROM node:20-slim AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Production stage
FROM node:20-slim

WORKDIR /app

# Copy built files and dependencies
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./

ENV TEMPORAL_HOST=temporal-frontend.temporal.svc.cluster.local:7233
ENV TEMPORAL_NAMESPACE=default

CMD ["node", "dist/worker.js"] 