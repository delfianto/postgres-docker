# postgres-docker

`ghcr.io/delfianto/postgres` bundles PostgreSQL 19.0, pgvector 0.8.7, and PGSTY VectorChord 1.5.0 for Linux amd64. The image uses the standard PostgreSQL entrypoint and preloads `vchord`.

| Tag | Versions |
| --- | --- |
| `19.0-0.8.7-1.5.0` | PostgreSQL, pgvector, and VectorChord versions in order |
| `19` | Latest build in this repository for PostgreSQL 19 |
| `latest` | Latest build from `main` |

## Run

The PostgreSQL entrypoint initializes a new cluster on the first start. Use `POSTGRES_PASSWORD_FILE` with a Docker secret or a read-only password file.

```sh
docker run -d --name postgres \
  --mount type=volume,source=postgres19,target=/var/lib/postgresql \
  --mount type=bind,source=/absolute/path/to/postgres_password,target=/run/secrets/postgres_password,readonly \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
  -p 127.0.0.1:5432:5432 \
  ghcr.io/delfianto/postgres:19.0-0.8.7-1.5.0
```

Enable VectorChord in each database that uses it. `CASCADE` enables `vector` as well.

```sh
docker exec postgres psql -U postgres -d postgres -c 'CREATE EXTENSION vchord CASCADE;'
```

Mount persistent storage at `/var/lib/postgresql`. PostgreSQL 19 stores the cluster under `/var/lib/postgresql/19/docker`. For a rootless Docker bind mount, make sure the container's `postgres` user can traverse the mounted parent directory and write to the cluster directory. A PostgreSQL 18 cluster must be migrated to a separate PostgreSQL 19 directory. [PostgreSQL upgrade documentation](https://www.postgresql.org/docs/19/upgrading.html)

## Build

```sh
docker build --platform linux/amd64 -t postgres-vchord:dev .
bash tests/smoke.sh postgres-vchord:dev
```

The Dockerfile pins the base image by digest and verifies the PGSTY release package with SHA-256. The workflow publishes only after the image can start PostgreSQL, load the expected extensions, and execute an indexed vector search.

## Upstream source and licenses

The build files use the repository's MIT license. The image includes upstream software under its respective licenses. VectorChord's release package includes its copyright and license information. [PostgreSQL 19.0 source](https://www.postgresql.org/ftp/source/v19.0/) · [pgvector 0.8.7 source](https://github.com/pgvector/pgvector/tree/v0.8.7) · [VectorChord 1.5.0 source and release files](https://github.com/pgsty/vchord/releases/tag/1.5.0)
