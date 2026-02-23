# ---------- BUILD STAGE ----------
FROM node:20-alpine AS builder

# Install build dependencies required by sharp/Strapi
RUN apk add --no-cache \
    build-base \
    gcc \
    autoconf \
    automake \
    zlib-dev \
    libpng-dev \
    vips-dev

WORKDIR /opt/app

# Copy package files and install dependencies cleanly
COPY package*.json ./
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build

# Strip out dev dependencies to keep the final image extremely lightweight
RUN npm prune --production

# ---------- PRODUCTION STAGE ----------
FROM node:20-alpine

# Install only the runtime dependency for sharp
RUN apk add --no-cache vips-dev

WORKDIR /opt/app

# Copy the optimized, pruned build from the builder stage
# We also change ownership to the non-root 'node' user
COPY --from=builder --chown=node:node /opt/app ./

ENV NODE_ENV=production

# Switch to the non-root user for better ECS security
USER node

EXPOSE 1337

CMD ["npm", "run", "start"]
