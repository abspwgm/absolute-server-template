#!/bin/bash
# =============================================================================
# Shared test helpers
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass()    { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail()    { echo -e "${RED}[FAIL]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }

log_test_start() {
    echo ""
    echo "----------------------------------------"
    echo "Starting test: $1"
    echo "----------------------------------------"
}

log_test_pass() {
    echo -e "${GREEN}Test PASSED: $1${NC}"
}

log_test_fail() {
    echo -e "${RED}Test FAILED: $1${NC}"
}

# The container name is derived from the manifest rather than written into each
# test, so a new game edits manifest.env and nothing else.
TEST_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${GAME_ID:-}" && -r "${TEST_PROJECT_ROOT}/manifest.env" ]]; then
    GAME_ID="$(sed -n 's/^GAME_ID=//p' "${TEST_PROJECT_ROOT}/manifest.env" | tr -d '"' | head -1)"
fi
CONTAINER="${CONTAINER:-${GAME_ID:-example}-server}"

# Every unit test collects failures rather than stopping at the first, so one
# run shows the whole distance.
CHECKS_FAILED=0

check() {
    local description="$1"
    shift
    if "$@"; then
        log_pass "${description}"
    else
        log_fail "${description}"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
}

finish() {
    local name="$1"
    if [[ ${CHECKS_FAILED} -gt 0 ]]; then
        log_test_fail "${name}: ${CHECKS_FAILED} check(s) failed"
        exit 1
    fi
    log_test_pass "${name}"
    exit 0
}

# Builds a valid manifest in ${1}, overriding any KEY=VALUE given after it.
write_manifest() {
    local path="$1"
    shift
    mkdir -p "$(dirname "${path}")"
    cat > "${path}" <<'MANIFEST'
GAME_ID=example
GAME_NAME="Example Server"
STEAM_APP_ID=896660
STEAM_LOGIN=anonymous
STEAM_BRANCH=public
STEAM_PLATFORM=linux
SERVER_BINARY=ExampleServer.sh
SERVER_PROCESS=ExampleServer-Linux-Shipping
STOP_SIGNAL=INT
STOP_TIMEOUT=90
READY_LOG_PATTERN='Server startup complete'
PUBLIC_PORTS=7777/udp
PRIVATE_PORTS=
SAVE_PATHS=saves
SNAPSHOT_PATHS=/opt/example/server
ADMIN_PASSWORD_VAR=
MOD_SOURCE=
MOD_EXPECT_PLUGINS=0
MANIFEST
    local override
    for override in "$@"; do
        local key="${override%%=*}"
        # Replace the line if present, append if not.
        if grep -q "^${key}=" "${path}"; then
            local escaped="${override//\//\\/}"
            sed -i "s/^${key}=.*/${escaped}/" "${path}"
        else
            echo "${override}" >> "${path}"
        fi
    done
}

# -----------------------------------------------------------------------------
# The runner's address stays out of the output
# -----------------------------------------------------------------------------
# On lab hardware the workflow learns the runner's public address, masks it in
# the job log and fails a suite that prints it, because a game learns that
# address from Steam and prints it, and a public repository's log is public.
# RUNNER_PUBLIC_ADDRESS holds the address(es) there, space-separated; anywhere
# else it is empty and nothing is hidden. A test never runs `docker logs`
# straight into its output: it goes through dump_container_logs.

# scrub_addresses ; a filter replacing every runner address with a placeholder
scrub_addresses() {
    local address expr=""
    for address in ${RUNNER_PUBLIC_ADDRESS:-}; do
        expr+="s/$(printf '%s' "${address}" | sed 's/[][\.*^$/]/\\&/g')/<runner-public-address>/g;"
    done
    if [[ -n "${expr}" ]]; then
        sed -e "${expr}"
    else
        cat
    fi
}

# dump_container_logs <container> [lines] ; the container's last lines, scrubbed
dump_container_logs() {
    docker logs "$1" --tail "${2:-40}" 2>&1 | scrub_addresses || true
}
