FROM node:20-alpine

WORKDIR /app

# Copy only the manifest files first. Docker caches each layer, so as long
# as package.json/package-lock.json don't change, this "npm ci" layer is
# reused on rebuild instead of re-downloading every dependency just
# because a controller file changed.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Now copy the rest of the source.
COPY . .

# node:alpine ships a pre-created unprivileged "node" user (uid 1000).
# Running the app as root inside the container is unnecessary risk: if a
# dependency vulnerability ever led to code execution, root in the
# container is a much bigger blast radius than an unprivileged user.
USER node

ENV NODE_ENV=production
EXPOSE 4000

# Used by `docker run --health...`, docker-compose, and later by
# Kubernetes-style liveness/readiness probes. Alpine's busybox provides
# wget, so no extra package (like curl) needs to be installed just for this.
# 127.0.0.1, not localhost: this one happens to work either way since
# Node's app.listen() binds dual-stack by default, but pinning to IPv4
# avoids relying on that and matches the fix we needed on the frontend.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:4000/health || exit 1

CMD ["node", "server.js"]
