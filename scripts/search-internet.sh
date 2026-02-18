#!/usr/bin/env bash
set -euo pipefail

SEARCH_ENDPOINT="http://localhost:8888/search"
SEARXNG_CONTAINER_NAME="searxng"
SEARXNG_IMAGE="docker.io/searxng/searxng:latest"
SEARXNG_WORKDIR="${HOME}/Documents/proj/searxng"
SEARXNG_CONFIG_DIR="${SEARXNG_WORKDIR}/config"
SEARXNG_DATA_DIR="${SEARXNG_WORKDIR}/data"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/search-internet"
LAST_SEARCH_FILE="${STATE_DIR}/last-search-epoch"
WATCHER_PID_FILE="${STATE_DIR}/watcher.pid"

IDLE_TIMEOUT_SECONDS=$((10 * 60))
WAIT_TIMEOUT_SECONDS=120
POLL_INTERVAL_SECONDS=5

usage() {
    echo "Usage: search-internet \"search query\"" >&2
    exit 1
}

start_docker_if_needed() {
    if docker info >/dev/null 2>&1; then
        return
    fi

    if command -v orp >/dev/null 2>&1; then
        orp start >/dev/null 2>&1 || true
    fi

    if command -v orb >/dev/null 2>&1; then
        orb start >/dev/null 2>&1 || true
    fi

    if command -v open >/dev/null 2>&1; then
        open -ga OrbStack >/dev/null 2>&1 || open -ga Docker >/dev/null 2>&1 || true
    fi

    local waited=0
    until docker info >/dev/null 2>&1; do
        sleep 2
        waited=$((waited + 2))
        if ((waited >= WAIT_TIMEOUT_SECONDS)); then
            echo "Docker did not become ready within ${WAIT_TIMEOUT_SECONDS}s." >&2
            exit 1
        fi
    done
}

searxng_is_ready() {
    curl -fsS --max-time 10 \
        --get \
        --data-urlencode "q=healthcheck" \
        --data "format=json" \
        "$SEARCH_ENDPOINT" >/dev/null 2>&1
}

container_is_running() {
    docker ps --filter "name=^/${SEARXNG_CONTAINER_NAME}$" --format '{{.Names}}' | grep -qx "${SEARXNG_CONTAINER_NAME}"
}

container_exists() {
    docker ps -a --filter "name=^/${SEARXNG_CONTAINER_NAME}$" --format '{{.Names}}' | grep -qx "${SEARXNG_CONTAINER_NAME}"
}

container_matches_expected_config() {
    local image mounts ports
    image="$(docker inspect -f '{{.Config.Image}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
    mounts="$(docker inspect -f '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
    ports="$(docker port "${SEARXNG_CONTAINER_NAME}" 8080/tcp 2>/dev/null || true)"

    [[ "$image" == "${SEARXNG_IMAGE}" || "$image" == "searxng/searxng:latest" ]] || return 1
    grep -Fqx "${SEARXNG_CONFIG_DIR} -> /etc/searxng" <<<"$mounts" || return 1
    grep -Fqx "${SEARXNG_DATA_DIR} -> /var/cache/searxng" <<<"$mounts" || return 1
    grep -Eq ':8888$' <<<"$ports" || return 1
}

start_search_container_if_needed() {
    mkdir -p "${SEARXNG_CONFIG_DIR}" "${SEARXNG_DATA_DIR}"

    if container_is_running && ! container_matches_expected_config; then
        docker rm -f "${SEARXNG_CONTAINER_NAME}" >/dev/null 2>&1 || true
    fi

    if ! container_is_running; then

        if container_exists; then
            docker rm -f "${SEARXNG_CONTAINER_NAME}" >/dev/null 2>&1 || true
        fi

        (
            cd "${SEARXNG_WORKDIR}"
            docker run --rm --name "${SEARXNG_CONTAINER_NAME}" -d \
                -p 8888:8080 \
                -v "./config/:/etc/searxng/" \
                -v "./data/:/var/cache/searxng/" \
                "${SEARXNG_IMAGE}" >/dev/null
        )
    fi

    local waited=0
    until searxng_is_ready; do
        sleep "$POLL_INTERVAL_SECONDS"
        waited=$((waited + POLL_INTERVAL_SECONDS))
        if ((waited >= WAIT_TIMEOUT_SECONDS)); then
            echo "SearXNG is not reachable at ${SEARCH_ENDPOINT}." >&2
            exit 1
        fi
    done
}

kill_search_container() {
    if ! docker info >/dev/null 2>&1; then
        return
    fi

    docker kill "${SEARXNG_CONTAINER_NAME}" >/dev/null 2>&1 || true
}

run_search_query() {
    local query="$1"
    local attempt=1

    while true; do
        if ((attempt < 3)); then
            if curl -fsS \
                --get \
                --data-urlencode "q=${query}" \
                --data "format=json" \
                "$SEARCH_ENDPOINT" 2>/dev/null; then
                return 0
            fi
        else
            curl -fsS \
                --get \
                --data-urlencode "q=${query}" \
                --data "format=json" \
                "$SEARCH_ENDPOINT"
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 1
    done
}

watch_for_idle_timeout() {
    while true; do
        if [[ ! -f "$LAST_SEARCH_FILE" ]]; then
            sleep "$POLL_INTERVAL_SECONDS"
            continue
        fi

        local now last
        now="$(date +%s)"
        last="$(cat "$LAST_SEARCH_FILE" 2>/dev/null || echo 0)"

        if [[ "$last" =~ ^[0-9]+$ ]] && ((now - last >= IDLE_TIMEOUT_SECONDS)); then
            kill_search_container
            rm -f "$WATCHER_PID_FILE"
            exit 0
        fi

        sleep "$POLL_INTERVAL_SECONDS"
    done
}

ensure_watcher_running() {
    if [[ -f "$WATCHER_PID_FILE" ]]; then
        local existing_pid
        existing_pid="$(cat "$WATCHER_PID_FILE" 2>/dev/null || true)"
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            return
        fi
    fi

    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    nohup "$script_path" --watch >/dev/null 2>&1 &
    echo "$!" >"$WATCHER_PID_FILE"
}

main() {
    mkdir -p "$STATE_DIR"

    if [[ "${1:-}" == "--watch" ]]; then
        watch_for_idle_timeout
        exit 0
    fi

    if [[ $# -ne 1 ]]; then
        usage
    fi

    local query="$1"
    start_docker_if_needed
    start_search_container_if_needed

    run_search_query "$query"

    date +%s >"$LAST_SEARCH_FILE"
    ensure_watcher_running
}

main "$@"
