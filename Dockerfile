FROM node:12-alpine AS base

ENV CHROME_BIN="/usr/bin/chromium-browser"
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD="true"
ENV CXXFLAGS="-Wno-ignored-qualifiers -Wno-stringop-truncation -Wno-cast-function-type"

WORKDIR /usr/src/app

RUN \
  apk add git && \
  git clone https://github.com/grafana/grafana-image-renderer.git && \
  mv ./grafana-image-renderer/* /usr/src/app/ && \
  rm -rf ./grafana-image-renderer

RUN \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
  apk --no-cache upgrade && \
  apk add --no-cache udev ttf-opensans chromium ca-certificates dumb-init && \
  rm -rf /tmp/*

RUN apk add --no-cache libc6-compat python alpine-sdk
RUN npm install -g node-gyp
RUN npm install --build-from-source=grpc

FROM base as build

COPY . ./

RUN yarn install --pure-lockfile
RUN yarn run build

EXPOSE 8081

CMD [ "yarn", "run", "dev" ]

FROM base

COPY --from=build /usr/src/app/node_modules node_modules
COPY --from=build /usr/src/app/build build
COPY --from=build /usr/src/app/proto proto
COPY --from=build /usr/src/app/dev.json config.json

EXPOSE 8081

ENTRYPOINT ["dumb-init", "--"]

CMD ["node", "build/app.js", "server", "--config=config.json"]
