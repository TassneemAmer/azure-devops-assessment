FROM node:24-alpine AS build

WORKDIR /src
COPY app/server.js ./server.js
RUN node --check server.js \
    && mkdir /dist \
    && cp server.js /dist/server.js

FROM node:24-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app
COPY --from=build --chown=node:node /dist/server.js ./server.js
USER node
EXPOSE 3000
CMD ["node", "server.js"]
