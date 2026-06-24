#!/usr/bin/env bash
set -euo pipefail

SEARCH_ENDPOINT="http://localhost:8888/search"
SEARCH_LANGUAGE="en"
SEARXNG_CONTAINER_NAME="searxng"
SEARXNG_IMAGE="docker.io/searxng/searxng:latest"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/search-internet"
RUNTIME_DIR="${STATE_DIR}/runtime"
SEARXNG_WORKDIR="${RUNTIME_DIR}"
SEARXNG_CONFIG_DIR="${RUNTIME_DIR}/config"
SEARXNG_DATA_DIR="${RUNTIME_DIR}/data"
SEARXNG_SETTINGS_PATH="/etc/searxng/search-internet.yml"
MANAGED_SETTINGS_FILE="${SEARXNG_CONFIG_DIR}/search-internet.yml"
MANAGED_SETTINGS_VERSION=1
LAST_SEARCH_FILE="${STATE_DIR}/last-search-epoch"
WATCHER_PID_FILE="${STATE_DIR}/watcher.pid"
WATCHER_VERSION_FILE="${STATE_DIR}/watcher.version"
WATCHER_LOG_FILE="${STATE_DIR}/watcher.log"
WATCHER_VERSION=2
CONTAINER_LOCK_DIR="${STATE_DIR}/container.lock"

IDLE_TIMEOUT_SECONDS=60
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
        --data "language=${SEARCH_LANGUAGE}" \
        --data "format=json" \
        "$SEARCH_ENDPOINT" >/dev/null 2>&1
}

container_is_running() {
    docker ps --filter "name=^/${SEARXNG_CONTAINER_NAME}$" --format '{{.Names}}' 2>/dev/null | grep -qx "${SEARXNG_CONTAINER_NAME}"
}

container_exists() {
    docker ps -a --filter "name=^/${SEARXNG_CONTAINER_NAME}$" --format '{{.Names}}' 2>/dev/null | grep -qx "${SEARXNG_CONTAINER_NAME}"
}

pull_latest_searxng_image() {
    docker pull "${SEARXNG_IMAGE}" >/dev/null
}

container_uses_current_image() {
    local container_image_id current_image_id
    container_image_id="$(docker inspect -f '{{.Image}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
    current_image_id="$(docker image inspect -f '{{.Id}}' "${SEARXNG_IMAGE}" 2>/dev/null || true)"

    [[ -n "$container_image_id" && "$container_image_id" == "$current_image_id" ]]
}

container_matches_expected_config() {
    local image mounts ports env
    image="$(docker inspect -f '{{.Config.Image}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
    mounts="$(docker inspect -f '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
    ports="$(docker port "${SEARXNG_CONTAINER_NAME}" 8080/tcp 2>/dev/null || true)"
    env="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"

    [[ "$image" == "${SEARXNG_IMAGE}" || "$image" == "searxng/searxng:latest" ]] || return 1
    grep -Fqx "${SEARXNG_CONFIG_DIR} -> /etc/searxng" <<<"$mounts" || return 1
    grep -Fqx "${SEARXNG_DATA_DIR} -> /var/cache/searxng" <<<"$mounts" || return 1
    grep -Eq ':8888$' <<<"$ports" || return 1
    grep -Fqx "SEARXNG_SETTINGS_PATH=${SEARXNG_SETTINGS_PATH}" <<<"$env" || return 1
}

extract_secret_key_setting() {
    local settings_file="$1"
    [[ -f "$settings_file" ]] || return 1

    awk '
        /^[[:space:]]*secret_key:[[:space:]]*/ {
            sub(/^[[:space:]]*secret_key:[[:space:]]*/, "")
            print
            exit
        }
    ' "$settings_file"
}

generate_secret_key_setting() {
    if command -v openssl >/dev/null 2>&1; then
        printf '"%s"\n' "$(openssl rand -hex 32)"
    elif command -v uuidgen >/dev/null 2>&1; then
        printf '"%s"\n' "$(uuidgen | tr -d '-')"
    else
        printf '"search-internet-%s"\n' "$(date +%s)"
    fi
}

ensure_managed_settings_file() {
    local secret_key tmp

    if [[ -f "$MANAGED_SETTINGS_FILE" ]] &&
        grep -Fqx "# search-internet-settings-version: ${MANAGED_SETTINGS_VERSION}" "$MANAGED_SETTINGS_FILE"; then
        return
    fi

    secret_key="$(extract_secret_key_setting "$MANAGED_SETTINGS_FILE" || true)"
    if [[ -z "$secret_key" ]]; then
        secret_key="$(generate_secret_key_setting)"
    fi

    tmp="$(mktemp "${MANAGED_SETTINGS_FILE}.XXXXXX")"
    cat >"$tmp" <<EOF
# search-internet-settings-version: ${MANAGED_SETTINGS_VERSION}
# Managed by search-internet.sh. Uses SearXNG defaults and only overrides command requirements.
use_default_settings: true

search:
  default_lang: "${SEARCH_LANGUAGE}"
  formats:
    - html
    - json

server:
  bind_address: "0.0.0.0"
  secret_key: ${secret_key}
  limiter: false
  public_instance: false
  method: "GET"
EOF
    mv "$tmp" "$MANAGED_SETTINGS_FILE"
}

cleanup_runtime_files() {
    rm -rf "$RUNTIME_DIR"
    rm -f "$LAST_SEARCH_FILE" "$WATCHER_PID_FILE" "$WATCHER_VERSION_FILE" "$WATCHER_LOG_FILE"
}

teardown_search_stack() {
    local image_id
    image_id=""

    if docker info >/dev/null 2>&1; then
        image_id="$(docker inspect -f '{{.Image}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
        docker rm -f "${SEARXNG_CONTAINER_NAME}" >/dev/null 2>&1 || true

        if [[ -n "$image_id" ]]; then
            docker image rm "$image_id" >/dev/null 2>&1 || true
        fi
        docker image rm "${SEARXNG_IMAGE}" >/dev/null 2>&1 || true
    fi

    cleanup_runtime_files
}

print_container_failure_and_exit() {
    local status
    status="$(docker inspect -f '{{.State.Status}}{{if .State.ExitCode}} (exit {{.State.ExitCode}}){{end}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
    if [[ -n "$status" ]]; then
        echo "SearXNG container stopped before it became ready: ${status}" >&2
    else
        echo "SearXNG container stopped before it became ready." >&2
    fi

    docker logs --tail 80 "${SEARXNG_CONTAINER_NAME}" >&2 2>/dev/null || true
    teardown_search_stack
    exit 1
}

acquire_container_lock() {
    local waited=0

    while ! mkdir "${CONTAINER_LOCK_DIR}" 2>/dev/null; do
        if [[ -f "${CONTAINER_LOCK_DIR}/pid" ]]; then
            local lock_pid
            lock_pid="$(cat "${CONTAINER_LOCK_DIR}/pid" 2>/dev/null || true)"
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                rm -rf "${CONTAINER_LOCK_DIR}"
                continue
            fi
        fi

        sleep 1
        waited=$((waited + 1))
        if ((waited >= WAIT_TIMEOUT_SECONDS)); then
            echo "Timed out waiting for the SearXNG container lock." >&2
            exit 1
        fi
    done

    echo "$$" >"${CONTAINER_LOCK_DIR}/pid"
}

release_container_lock() {
    rm -rf "${CONTAINER_LOCK_DIR}"
}

ensure_container_running_locked() {
    ensure_managed_settings_file
    pull_latest_searxng_image

    if container_exists; then
        local old_image_id uses_current
        old_image_id="$(docker inspect -f '{{.Image}}' "${SEARXNG_CONTAINER_NAME}" 2>/dev/null || true)"
        uses_current=1
        container_uses_current_image || uses_current=0

        if ! container_matches_expected_config || ((uses_current == 0)); then
            docker rm -f "${SEARXNG_CONTAINER_NAME}" >/dev/null 2>&1 || true
            if ((uses_current == 0)) && [[ -n "$old_image_id" ]]; then
                docker image rm "$old_image_id" >/dev/null 2>&1 || true
            fi
        elif container_is_running; then
            return
        else
            docker start "${SEARXNG_CONTAINER_NAME}" >/dev/null
            return
        fi
    fi

    if (
        cd "${SEARXNG_WORKDIR}"
        docker run --name "${SEARXNG_CONTAINER_NAME}" -d \
            -p 8888:8080 \
            -e "SEARXNG_SETTINGS_PATH=${SEARXNG_SETTINGS_PATH}" \
            -v "./config/:/etc/searxng/" \
            -v "./data/:/var/cache/searxng/" \
            "${SEARXNG_IMAGE}" >/dev/null
    ); then
        return
    fi

    if ! container_exists || ! container_matches_expected_config; then
        echo "Failed to start the SearXNG container." >&2
        exit 1
    fi

    if ! container_is_running; then
        docker start "${SEARXNG_CONTAINER_NAME}" >/dev/null
    fi
}

start_search_container_if_needed() {
    mkdir -p "${SEARXNG_CONFIG_DIR}" "${SEARXNG_DATA_DIR}" "${STATE_DIR}"

    ensure_container_running_locked

    local waited=0
    until searxng_is_ready; do
        if ! container_is_running; then
            print_container_failure_and_exit
        fi

        sleep "$POLL_INTERVAL_SECONDS"
        waited=$((waited + POLL_INTERVAL_SECONDS))
        if ((waited >= WAIT_TIMEOUT_SECONDS)); then
            echo "SearXNG is not reachable at ${SEARCH_ENDPOINT}." >&2
            docker logs --tail 80 "${SEARXNG_CONTAINER_NAME}" >&2 2>/dev/null || true
            teardown_search_stack
            exit 1
        fi
    done
}

run_search_query() {
    local query="$1"
    local attempt=1

    while true; do
        if ((attempt < 3)); then
            if curl -fsS \
                --get \
                --data-urlencode "q=${query}" \
                --data "language=${SEARCH_LANGUAGE}" \
                --data "format=json" \
                "$SEARCH_ENDPOINT" 2>/dev/null; then
                return 0
            fi
        else
            if curl -fsS \
                --get \
                --data-urlencode "q=${query}" \
                --data "language=${SEARCH_LANGUAGE}" \
                --data "format=json" \
                "$SEARCH_ENDPOINT"; then
                return 0
            fi
            return 1
        fi

        attempt=$((attempt + 1))
        sleep 1
    done
}

watch_for_idle_timeout() {
    while true; do
        if [[ ! -f "$LAST_SEARCH_FILE" ]]; then
            if ! container_exists; then
                cleanup_runtime_files
                rmdir "$STATE_DIR" 2>/dev/null || true
                exit 0
            fi

            sleep "$POLL_INTERVAL_SECONDS"
            continue
        fi

        local now last
        now="$(date +%s)"
        last="$(cat "$LAST_SEARCH_FILE" 2>/dev/null || echo 0)"

        if [[ "$last" =~ ^[0-9]+$ ]] && ((now - last >= IDLE_TIMEOUT_SECONDS)); then
            acquire_container_lock
            trap release_container_lock EXIT

            now="$(date +%s)"
            last="$(cat "$LAST_SEARCH_FILE" 2>/dev/null || echo 0)"
            if [[ "$last" =~ ^[0-9]+$ ]] && ((now - last >= IDLE_TIMEOUT_SECONDS)); then
                teardown_search_stack
                release_container_lock
                trap - EXIT
                rmdir "$STATE_DIR" 2>/dev/null || true
                exit 0
            fi

            release_container_lock
            trap - EXIT
        fi

        sleep "$POLL_INTERVAL_SECONDS"
    done
}

ensure_watcher_running() {
    if [[ -f "$WATCHER_PID_FILE" ]]; then
        local existing_pid existing_version
        existing_pid="$(cat "$WATCHER_PID_FILE" 2>/dev/null || true)"
        existing_version="$(cat "$WATCHER_VERSION_FILE" 2>/dev/null || true)"
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null &&
            [[ "$existing_version" == "$WATCHER_VERSION" ]]; then
            return
        fi
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            kill "$existing_pid" 2>/dev/null || true
        fi
    fi

    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    nohup bash "$script_path" --watch >"$WATCHER_LOG_FILE" 2>&1 &
    echo "$!" >"$WATCHER_PID_FILE"
    echo "$WATCHER_VERSION" >"$WATCHER_VERSION_FILE"
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
    local search_status=0

    acquire_container_lock
    trap release_container_lock EXIT

    start_docker_if_needed
    start_search_container_if_needed
    date +%s >"$LAST_SEARCH_FILE"

    run_search_query "$query" || search_status=$?
    date +%s >"$LAST_SEARCH_FILE"
    ensure_watcher_running

    release_container_lock
    trap - EXIT
    return "$search_status"
}

main "$@"
