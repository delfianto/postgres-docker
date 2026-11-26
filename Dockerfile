# syntax=docker/dockerfile:1

ARG BASE_IMAGE=pgvector/pgvector:0.8.7-pg19-bookworm@sha256:9fd1e61398799f1d6b64a852bce2bb59863c0ebbcd96178e20c7b10059e9ea5e

FROM ${BASE_IMAGE} AS extension
ADD --checksum=sha256:ae2c40877942f4882c7ebb7ef02553e6f2c83d5800ae98bc8a9bdc92342edf9e \
    https://github.com/pgsty/vchord/releases/download/1.5.0/postgresql-19-vchord_1.5.0-1_amd64.deb \
    /tmp/vchord.deb
RUN dpkg-deb --extract /tmp/vchord.deb /vchord

FROM ${BASE_IMAGE}
COPY --from=extension /vchord/ /

LABEL org.opencontainers.image.source="https://github.com/delfianto/postgres-docker" \
      org.opencontainers.image.description="PostgreSQL 19 with pgvector and PGSTY VectorChord" \
      org.opencontainers.image.version="19.0-0.8.7-1.5.0"

CMD ["postgres", "-c", "shared_preload_libraries=vchord"]
