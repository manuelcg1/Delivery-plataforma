FROM node:20.19.5-alpine3.21 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
FROM node:20.19.5-alpine3.21 AS builder
WORKDIR /app
ARG NEXT_PUBLIC_API_URL=http://localhost:8080
ARG NEXT_PUBLIC_WS_URL=ws://localhost:8080/ws
ARG API_INTERNAL_URL=http://backend:8080
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL NEXT_PUBLIC_WS_URL=$NEXT_PUBLIC_WS_URL API_INTERNAL_URL=$API_INTERNAL_URL
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm test && npm run lint && npm run build
FROM node:20.19.5-alpine3.21 AS runner
WORKDIR /app
ENV NODE_ENV=production PORT=3001 HOSTNAME=0.0.0.0
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 merchant
COPY --from=builder --chown=merchant:nodejs /app/.next/standalone ./
COPY --from=builder --chown=merchant:nodejs /app/.next/static ./.next/static
USER merchant
EXPOSE 3001
CMD ["node","server.js"]
