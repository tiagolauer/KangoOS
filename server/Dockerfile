FROM dart:stable AS build

WORKDIR /build

COPY core ./core
COPY server ./server

WORKDIR /build/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o /build/server.exe

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends libsqlite3-0 ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/server.exe /app/server

ENV KANGOOS_DB_PATH=/data/kangoos.db
VOLUME /data
EXPOSE 8080

ENTRYPOINT ["/app/server"]
