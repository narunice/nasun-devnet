#!/bin/bash
# =================================================================
# Nasun Devnet - Fullnode Resync Trigger
# Checks disk usage and triggers resync if threshold exceeded
# Runs via cron every 6 hours
# =================================================================

LOCK_FILE="/home/ubuntu/.fullnode-resync.lock"
LOG_FILE="/home/ubuntu/fullnode-resync.log"
DISK_THRESHOLD=80  # architect 권장: 80%
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Get disk usage
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

# Skip if resync already running
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "[$TIMESTAMP] Resync already running (PID: $LOCK_PID). Skipping." >> "$LOG_FILE"
        exit 0
    fi
fi

# Trigger resync if threshold exceeded
if [ "$USAGE" -ge "$DISK_THRESHOLD" ]; then
    echo "[$TIMESTAMP] TRIGGER: Disk at ${USAGE}% (threshold: ${DISK_THRESHOLD}%). Starting resync..." >> "$LOG_FILE"
    /home/ubuntu/fullnode-resync.sh >> "$LOG_FILE" 2>&1 &
else
    # Log if disk is above 70% (visibility without noise)
    if [ "$USAGE" -ge 70 ]; then
        echo "[$TIMESTAMP] CHECK: Disk at ${USAGE}% (threshold: ${DISK_THRESHOLD}%). No action." >> "$LOG_FILE"
    fi
fi
