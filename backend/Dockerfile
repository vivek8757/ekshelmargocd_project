# Build / Dependency Install stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production runner stage
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
COPY src/ ./src/

EXPOSE 5000
ENV PORT=5000
ENV NODE_ENV=production

# Run as non-root user for security in Kubernetes
USER node

CMD ["node", "src/server.js"]
