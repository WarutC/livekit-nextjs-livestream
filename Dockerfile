# syntax=docker/dockerfile:1
ARG BUILDPLATFORM="linux/amd64"

ARG NODE_VERSION=22.15.0
ARG PNPM_VERSION=10.11.0

################################################################################
# Use node image for base image for all stages.
FROM node:${NODE_VERSION}-alpine AS base

# Set working directory for all build stages.
RUN mkdir -p /home/node/app && chown -R node:node /home/node/app
WORKDIR /home/node/app

# Install pnpm.
RUN --mount=type=cache,target=/root/.npm \
    npm install -g pnpm@${PNPM_VERSION}
    
RUN pnpm config set ignore-scripts true
# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /root/.local/share/pnpm/store to speed up subsequent builds.
# Leverage bind mounts to package.json and pnpm-lock.yaml to avoid having to copy them
# into this layer.
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install

################################################################################
# Development stage.
FROM base AS development

ENV TZ=Asia/Bangkok
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /home/node/app

COPY . .

# Expose the port the app runs on
EXPOSE 3000

CMD ["pnpm", "dev"]

################################################################################
# Create a stage for building the application.
FROM base AS builder

WORKDIR /home/node/app
    
COPY . .

# Use production node environment by default.
ENV NODE_ENV=production

RUN pnpm run build

################################################################################
FROM node:${NODE_VERSION}-alpine AS production

ENV TZ=Asia/Bangkok
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV NODE_ENV=production

# Install pnpm globally
RUN npm install -g pnpm@${PNPM_VERSION}

# Install pm2 globally
RUN npm install -g pm2

# Set the working directory inside the container
WORKDIR /home/node/app

# Copy the built application from the builder stage
COPY --from=builder /home/node/app/.next ./.next
COPY --from=builder /home/node/app/package.json ./
COPY --from=builder /home/node/app/public ./public

# Install only production dependencies
RUN pnpm install --prod

# Expose the port the app runs on
EXPOSE 3000

# Start the application using pm2
CMD ["pm2-runtime", "start", "node_modules/next/dist/bin/next", "--", "start"]
