FROM dart:3.7.3 AS build

WORKDIR /build

COPY core ./core
COPY server ./server

WORKDIR /build/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o /build/server.exe

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends libsqlite3-0 ca-certificates \
  && sqlite_library="$(find /usr/lib -name libsqlite3.so.0 -print -quit)" \
  && test -n "$sqlite_library" \
  && ln -s "$sqlite_library" /usr/lib/libsqlite3.so \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/server.exe /app/server

ENV KANGOOS_DB_PATH=/data/kangoos.db
VOLUME /data
EXPOSE 8080

ENTRYPOINT ["/app/server"]
