#!/bin/bash
# =================================================================
# Nasun Devnet - Fullnode DB Resync Script
# Purpose: Delete fullnode DB and resync from genesis to reclaim disk
# Impact: RPC downtime during resync (3-6 hours estimated)
# Safety: Validator continues running, consensus unaffected
# =================================================================

set -euo pipefail

# --- Configuration ---
LOCK_FILE="/home/ubuntu/.fullnode-resync.lock"
LOG_FILE="/home/ubuntu/fullnode-resync.log"
LAST_RESYNC_FILE="/home/ubuntu/.last-resync-time"
FULLNODE_DB_PATH="/home/ubuntu/full_node_db"
FULLNODE_SERVICE="nasun-fullnode"
FAUCET_SERVICE="nasun-faucet"
VALIDATOR_SERVICE="nasun-validator"
RPC_URL="http://127.0.0.1:9000"
SNS_TOPIC_ARN="arn:aws:sns:ap-northeast-2:150674276464:nasun-devnet-alerts"
HOSTNAME=$(hostname)

# Configurable parameters
SYNC_CHECK_INTERVAL=300       # 5 minutes
SYNC_TIMEOUT=21600            # 6 hours
SYNC_STALE_THRESHOLD=3        # 3 consecutive stale checks
COOLDOWN_HOURS=24             # Minimum 24h between resyncs
CHECKPOINT_SYNC_THRESHOLD=100 # Faucet starts when within 100 checkpoints

# --- Log rotation ---
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

# --- Functions ---
log() {
    local TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
    logger -t fullnode-resync "$1"
}

sns_notify() {
    local SUBJECT="$1"
    local MESSAGE="$2"
    aws sns publish \
        --region ap-northeast-2 \
        --topic-arn "$SNS_TOPIC_ARN" \
        --subject "$SUBJECT" \
        --message "$MESSAGE" 2>/dev/null || true
}

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
            log "ERROR: Resync already running (PID: $LOCK_PID). Aborting."
            exit 1
        fi
        log "WARN: Stale lock file found. Removing."
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

cleanup() {
    release_lock
    log "Cleanup complete. Lock released."
}

check_cooldown() {
    if [ -f "$LAST_RESYNC_FILE" ]; then
        local LAST_TIME=$(cat "$LAST_RESYNC_FILE")
        local NOW=$(date +%s)
        local ELAPSED=$(( (NOW - LAST_TIME) / 3600 ))

        if [ "$ELAPSED" -lt "$COOLDOWN_HOURS" ]; then
            log "SKIP: Last resync was ${ELAPSED}h ago (cooldown: ${COOLDOWN_HOURS}h)"
            exit 0
        fi
    fi
}

get_disk_usage() {
    df / | tail -1 | awk '{print $5}' | sed 's/%//'
}

get_disk_avail_gb() {
    df -BG / | tail -1 | awk '{print $4}' | sed 's/G//'
}

get_db_size_gb() {
    if [ -d "$FULLNODE_DB_PATH" ]; then
        du -s --block-size=1G "$FULLNODE_DB_PATH" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

check_validator_running() {
    systemctl is-active --quiet "$VALIDATOR_SERVICE"
}

get_checkpoint() {
    local URL="$1"
    local RESPONSE=$(curl -s --max-time 10 -X POST "$URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' 2>/dev/null || echo "")

    if echo "$RESPONSE" | jq -e '.result' >/dev/null 2>&1; then
        echo "$RESPONSE" | jq -r '.result'
    else
        echo "error"
    fi
}

# --- Pre-flight Checks ---
preflight_checks() {
    log "=== PRE-FLIGHT CHECKS ==="

    # Cooldown check
    check_cooldown

    # Validator must be running
    if ! check_validator_running; then
        log "CRITICAL: Validator is not running. Aborting resync."
        sns_notify "Nasun Resync ABORTED - ${HOSTNAME}" \
            "Fullnode DB resync aborted: Validator is not running."
        release_lock
        exit 1
    fi
    log "Validator: running"

    # Record disk state
    local DISK_USAGE=$(get_disk_usage)
    local DISK_AVAIL=$(get_disk_avail_gb)
    local DB_SIZE=$(get_db_size_gb)
    log "Disk: ${DISK_USAGE}% used, ${DISK_AVAIL}GB available"
    log "Fullnode DB: ${DB_SIZE}GB"

    # Record current checkpoint
    local CHECKPOINT=$(get_checkpoint "$RPC_URL")
    if [ "$CHECKPOINT" != "error" ]; then
        log "Current checkpoint: $CHECKPOINT"
    else
        log "RPC not available (fullnode may be down)"
    fi
}

# --- Main Resync Process ---
do_resync() {
    log "=== STARTING FULLNODE DB RESYNC ==="

    local DISK_BEFORE=$(get_disk_usage)
    local DB_SIZE_BEFORE=$(get_db_size_gb)
    local AVAIL_BEFORE=$(get_disk_avail_gb)

    sns_notify "Nasun Fullnode Resync STARTED - ${HOSTNAME}" \
        "Fullnode DB resync initiated on ${HOSTNAME}.
Disk: ${DISK_BEFORE}% used, ${AVAIL_BEFORE}GB available
Fullnode DB: ${DB_SIZE_BEFORE}GB
RPC will be unavailable during resync (estimated 3-6 hours)."

    # Stop Faucet
    log "Stopping faucet service..."
    sudo systemctl stop "$FAUCET_SERVICE" 2>/dev/null || true
    sleep 2

    # Stop Fullnode
    log "Stopping fullnode service..."
    sudo systemctl stop "$FULLNODE_SERVICE"
    sleep 5

    if systemctl is-active --quiet "$FULLNODE_SERVICE"; then
        log "ERROR: Fullnode did not stop. Force killing..."
        sudo systemctl kill -s SIGKILL "$FULLNODE_SERVICE" 2>/dev/null || true
        sleep 3
    fi
    log "Fullnode stopped."

    # Delete DB
    log "Deleting fullnode DB at ${FULLNODE_DB_PATH}..."
    if [ -d "$FULLNODE_DB_PATH" ]; then
        rm -rf "$FULLNODE_DB_PATH"
        log "Fullnode DB deleted. Freed: ${DB_SIZE_BEFORE}GB"
    else
        log "Fullnode DB not found. Skipping delete."
    fi

    local DISK_AFTER_DELETE=$(get_disk_usage)
    local AVAIL_AFTER=$(get_disk_avail_gb)
    log "Disk after delete: ${DISK_AFTER_DELETE}% (${AVAIL_AFTER}GB available)"

    # Restart Fullnode
    log "Starting fullnode service (resync from genesis)..."
    sudo systemctl start "$FULLNODE_SERVICE"
    sleep 10

    if ! systemctl is-active --quiet "$FULLNODE_SERVICE"; then
        log "CRITICAL: Fullnode failed to start!"
        sns_notify "Nasun Resync FAILED - ${HOSTNAME}" \
            "CRITICAL: Fullnode failed to start after DB deletion.
Manual intervention required."
        release_lock
        exit 1
    fi
    log "Fullnode started. Syncing from genesis..."

    # Monitor sync
    log "Monitoring sync progress (timeout: ${SYNC_TIMEOUT}s)..."
    monitor_sync_progress

    # Restart Faucet
    log "Restarting faucet service..."
    sudo systemctl start "$FAUCET_SERVICE"
    sleep 5

    if systemctl is-active --quiet "$FAUCET_SERVICE"; then
        log "Faucet started."
    else
        log "WARN: Faucet failed to start."
    fi

    # Final report
    local DISK_FINAL=$(get_disk_usage)
    local DB_SIZE_FINAL=$(get_db_size_gb)
    local CHECKPOINT_FINAL=$(get_checkpoint "$RPC_URL")

    log "=== RESYNC COMPLETE ==="
    log "Disk: ${DISK_BEFORE}% -> ${DISK_FINAL}%"
    log "DB size: ${DB_SIZE_BEFORE}GB -> ${DB_SIZE_FINAL}GB"
    log "Checkpoint: $CHECKPOINT_FINAL"

    # Record resync time
    date +%s > "$LAST_RESYNC_FILE"

    sns_notify "Nasun Fullnode Resync COMPLETE - ${HOSTNAME}" \
        "Fullnode DB resync completed on ${HOSTNAME}.
Disk: ${DISK_BEFORE}% -> ${DISK_FINAL}%
DB: ${DB_SIZE_BEFORE}GB -> ${DB_SIZE_FINAL}GB
Checkpoint: $CHECKPOINT_FINAL"
}

monitor_sync_progress() {
    local ELAPSED=0
    local STALE_COUNT=0
    local PREV_CHECKPOINT=""

    while [ "$ELAPSED" -lt "$SYNC_TIMEOUT" ]; do
        sleep "$SYNC_CHECK_INTERVAL"
        ELAPSED=$((ELAPSED + SYNC_CHECK_INTERVAL))

        # Check validator still running
        if ! check_validator_running; then
            log "CRITICAL: Validator died during resync!"
            sns_notify "Nasun Resync FAILED - ${HOSTNAME}" \
                "Validator crashed during fullnode resync. Manual intervention required."
            exit 1
        fi

        # Check fullnode still running
        if ! systemctl is-active --quiet "$FULLNODE_SERVICE"; then
            log "CRITICAL: Fullnode died during resync!"
            sns_notify "Nasun Resync FAILED - ${HOSTNAME}" \
                "Fullnode crashed during resync. Attempting restart..."
            sudo systemctl start "$FULLNODE_SERVICE"
            sleep 10
        fi

        local CURRENT=$(get_checkpoint "$RPC_URL")

        if [ "$CURRENT" = "error" ]; then
            log "Sync progress: RPC not ready (${ELAPSED}s elapsed)"
            continue
        fi

        if [ "$CURRENT" = "$PREV_CHECKPOINT" ] && [ -n "$PREV_CHECKPOINT" ]; then
            STALE_COUNT=$((STALE_COUNT + 1))
            log "Sync progress: checkpoint $CURRENT (stale: $STALE_COUNT)"
        else
            STALE_COUNT=0
            log "Sync progress: checkpoint $CURRENT (${ELAPSED}s elapsed)"
        fi

        PREV_CHECKPOINT="$CURRENT"

        if [ "$STALE_COUNT" -ge "$SYNC_STALE_THRESHOLD" ]; then
            log "WARN: Sync stuck at checkpoint $CURRENT. Continuing to monitor..."
            break
        fi
    done

    if [ "$ELAPSED" -ge "$SYNC_TIMEOUT" ]; then
        log "WARN: Sync timeout after ${SYNC_TIMEOUT}s"
        sns_notify "Nasun Resync TIMEOUT - ${HOSTNAME}" \
            "Fullnode resync timed out after ${SYNC_TIMEOUT}s.
Last checkpoint: $PREV_CHECKPOINT
Fullnode will continue syncing in background."
    fi
}

# --- Main ---
trap cleanup EXIT

acquire_lock
preflight_checks
do_resync
release_lock

log "Resync script completed successfully."
