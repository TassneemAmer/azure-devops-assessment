FROM node:24-alpine AS build

WORKDIR /src
COPY package*.json ./
RUN npm ci --omit=dev
COPY app/server.js ./server.js
RUN node --check server.js \
    && mkdir /dist \
    && cp server.js /dist/server.js

FROM node:24-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app
COPY --from=build --chown=node:node /dist/server.js ./server.js
COPY --from=build --chown=node:node /src/node_modules ./node_modules
USER node
EXPOSE 3000
CMD ["node", "server.js"]
