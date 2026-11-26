#!/usr/bin/env bash
set -euo pipefail

image=${1:?Usage: bash tests/smoke.sh IMAGE}
expected_versions=$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$image")

# The temporary server has no published ports or network access.
container=$(docker run --detach --network none \
  --tmpfs /var/lib/postgresql:rw,size=128m,mode=1777 \
  --env POSTGRES_HOST_AUTH_METHOD=trust "$image")
cleanup() {
  docker stop -t 10 "$container" >/dev/null 2>&1 || true
  docker rm -v "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for (( attempt = 0; attempt < 30; attempt++ )); do
  if docker exec "$container" pg_isready --quiet --host=127.0.0.1 --username=postgres 2>/dev/null; then
    break
  fi
  if [[ $(docker inspect --format '{{.State.Running}}' "$container") == false ]]; then
    break
  fi
  sleep 1
done
if ! docker exec "$container" pg_isready --host=127.0.0.1 --username=postgres; then
  docker logs "$container" >&2
  exit 1
fi

result=$(docker exec --interactive "$container" psql -XqAt --username=postgres --set=ON_ERROR_STOP=1 <<'SQL'
CREATE EXTENSION vchord CASCADE;
CREATE EXTENSION earthdistance CASCADE;
CREATE EXTENSION pg_trgm;
CREATE EXTENSION unaccent;
CREATE EXTENSION "uuid-ossp";

SELECT concat_ws('-', split_part(current_setting('server_version'), ' ', 1),
  (SELECT extversion FROM pg_extension WHERE extname = 'vector'),
  (SELECT extversion FROM pg_extension WHERE extname = 'vchord'));

CREATE TABLE smoke_vectors (id integer PRIMARY KEY, embedding vector(3));
INSERT INTO smoke_vectors VALUES (1, '[0,0,0]'), (2, '[1,2,3]'), (3, '[3,2,1]');
CREATE INDEX smoke_vector_lookup ON smoke_vectors USING vchordrq (embedding vector_l2_ops);
SET enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT id FROM smoke_vectors ORDER BY embedding <-> '[1,2,3]' LIMIT 1;
SELECT id FROM smoke_vectors ORDER BY embedding <-> '[1,2,3]' LIMIT 1;
SQL
)

printf '%s\n' "$result"
[[ "${result%%$'\n'*}" == "$expected_versions" ]]
grep -Fq 'Index Scan using smoke_vector_lookup' <<< "$result"
[[ "${result##*$'\n'}" == 2 ]]
