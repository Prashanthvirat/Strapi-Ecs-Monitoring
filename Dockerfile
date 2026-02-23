# ---------- BUILD STAGE ----------
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    gcc \
    autoconf \
    automake \
    zlib-dev \
    libpng-dev \
    vips-dev

WORKDIR /opt/app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build


# ---------- PRODUCTION STAGE ----------
FROM node:20-alpine

WORKDIR /opt/app

# Install only runtime dependency for sharp
RUN apk add --no-cache vips-dev

COPY --from=builder /opt/app ./

ENV NODE_ENV=production

EXPOSE 1337

CMD ["npm", "run", "start"]
