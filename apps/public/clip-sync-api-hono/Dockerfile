FROM oven/bun:1.3.14-alpine AS dependencies
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

FROM dependencies AS development
COPY . .
CMD ["bun", "run", "dev"]

FROM oven/bun:1.3.14-alpine AS production-dependencies
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile --production

FROM oven/bun:1.3.14-alpine AS production
ENV CLIP_SYNC_ENV=production
WORKDIR /app
COPY --from=production-dependencies /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
USER bun
CMD ["sh", "-c", "bun run db:migrate && bun run start"]
