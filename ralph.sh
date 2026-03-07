#!/bin/bash

# Ralph Wiggum Loop Starter
# Runs Claude Code in headless mode, one task per iteration, fresh context each time.
# https://github.com/nearestnabors/ralph-wiggum-loop-starter

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_DIR/ralph-logs"
mkdir -p "$LOG_DIR"

# ── Configuration (override with environment variables) ─────────────────────

# What to do when rate-limited:
#   "wait"      — sleep until reset, then resume (no matter what time it is)
#   "stop"      — exit the loop immediately
#   "overnight" — sleep until reset IF it's before WAKE_HOUR, otherwise stop
ON_LIMIT="${ON_LIMIT:-overnight}"

# Hour you wake up (24h format). In overnight mode, Ralph won't resume after
# this time so your morning tokens are preserved. Default: 10 (10am)
WAKE_HOUR="${WAKE_HOUR:-10}"

# Allowed tools for Claude Code. Override to match your stack.
# Default is for Node.js projects. See README for Python example.
ALLOWED_TOOLS="${ALLOWED_TOOLS:-Read,Write,Edit,Bash(npm *),Bash(npx *),Bash(node *),Bash(cat *),Bash(ls *),Bash(mkdir *),Bash(grep *),Bash(git status *),Bash(git diff *),Bash(git checkout *),Bash(git stash *),Bash(git log *)}"

# ── Sanity checks ───────────────────────────────────────────────────────────

for f in spec.md implementation-plan.md prompt.md; do
    if [ ! -f "$PROJECT_DIR/$f" ]; then
        echo "❌ Missing required file: $f"
        exit 1
    fi
done

if ! command -v claude &> /dev/null; then
    echo "❌ Claude Code not found. Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not inside a git repository. Ralph needs git for auto-commits."
    exit 1
fi

UNCHECKED=$(grep -c -- '- \[ \]' "$PROJECT_DIR/implementation-plan.md" || true)

if [ "$UNCHECKED" -eq 0 ]; then
    echo "⚠️  No unchecked tasks found in implementation-plan.md."
    echo "   Make sure tasks use this format: - [ ] Task description (indentation is fine)"
    exit 0
fi

# ── Start ────────────────────────────────────────────────────────────────────

ITERATION=0

echo "🔁 Starting Ralph Wiggum Loop..."
echo "   Project:  $PROJECT_DIR"
echo "   Logs:     $LOG_DIR"
echo "   Tasks:    $UNCHECKED unchecked"
echo "   On limit: $ON_LIMIT (wake hour: $WAKE_HOUR)"
echo ""

while true; do
    ITERATION=$((ITERATION + 1))
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOG_FILE="$LOG_DIR/iteration_${ITERATION}_${TIMESTAMP}.log"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Iteration $ITERATION — $(date)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # ── Stopping conditions ──────────────────────────────────────────────

    # All tasks complete
    if [ -f "$PROJECT_DIR/DONE" ]; then
        echo "✅ All tasks complete! DONE file found."
        break
    fi

    # All checkboxes checked
    REMAINING=$(grep -c -- '- \[ \]' "$PROJECT_DIR/implementation-plan.md" || true)
    if [ "$REMAINING" -eq 0 ]; then
        echo "✅ All tasks checked off in implementation-plan.md"
        break
    fi

    # All remaining tasks have 3+ failure notes — stuck
    STUCK=$(awk '
        /- \[ \]/ {
            if (warns >= 3) stuck++
            warns = 0
            next
        }
        /⚠️/ { warns++ }
        END {
            if (warns >= 3) stuck++
            print stuck + 0
        }
    ' "$PROJECT_DIR/implementation-plan.md")

    if [ "$STUCK" -ge "$REMAINING" ] && [ "$REMAINING" -gt 0 ]; then
        echo "🚧 All $REMAINING remaining tasks have 3+ failures. Human intervention needed."
        echo "   Review implementation-plan.md for ⚠️ notes."
        break
    fi

    # ── Run Claude ───────────────────────────────────────────────────────

    TASKS_BEFORE=$(grep -c -- '- \[x\]' "$PROJECT_DIR/implementation-plan.md" 2>/dev/null || echo 0)

    echo "🤖 Running Claude Code (headless)..."
    cd "$PROJECT_DIR" || exit 1

    claude -p "$(cat prompt.md)" \
        --allowedTools "$ALLOWED_TOOLS" \
        2>&1 | tee "$LOG_FILE"

    EXIT_CODE=${PIPESTATUS[0]}

    # ── Handle rate limits and errors ─────────────────────────────────────

    # Check for rate limit regardless of exit code
    if grep -q "hit your limit" "$LOG_FILE" 2>/dev/null; then
        RESET_MSG=$(grep -o 'resets [0-9]*[ap]m' "$LOG_FILE" | head -1)

        if [ "$ON_LIMIT" = "stop" ]; then
            echo "🛑 Rate limit hit. $RESET_MSG. Stopping (ON_LIMIT=stop)."
            break
        fi

        # Calculate seconds until reset
        if [ -n "$RESET_MSG" ]; then
            RESET_HOUR=$(echo "$RESET_MSG" | grep -o '[0-9]*[ap]m')
            HOUR_NUM=$(echo "$RESET_HOUR" | grep -o '[0-9]*')
            if echo "$RESET_HOUR" | grep -q 'pm'; then
                [ "$HOUR_NUM" -ne 12 ] && HOUR_NUM=$((HOUR_NUM + 12))
            else
                [ "$HOUR_NUM" -eq 12 ] && HOUR_NUM=0
            fi
            NOW_EPOCH=$(date +%s)
            RESET_EPOCH=$(date -j -v"${HOUR_NUM}H" -v0M -v0S +%s 2>/dev/null || date -d "today ${HOUR_NUM}:00" +%s 2>/dev/null)
            if [ "$RESET_EPOCH" -le "$NOW_EPOCH" ]; then
                RESET_EPOCH=$((RESET_EPOCH + 86400))
            fi

            # Overnight mode: stop if reset is after wake time
            if [ "$ON_LIMIT" = "overnight" ]; then
                WAKE_EPOCH=$(date -j -v"${WAKE_HOUR}H" -v0M -v0S +%s 2>/dev/null || date -d "today ${WAKE_HOUR}:00" +%s 2>/dev/null)
                if [ "$WAKE_EPOCH" -le "$NOW_EPOCH" ]; then
                    WAKE_EPOCH=$((WAKE_EPOCH + 86400))
                fi
                if [ "$RESET_EPOCH" -ge "$WAKE_EPOCH" ]; then
                    echo "🌙 Rate limit hit. $RESET_MSG (after your ${WAKE_HOUR}:00 wake time). Stopping to preserve your morning tokens."
                    echo "   Resume in the morning with: ./ralph.sh"
                    break
                fi
            fi

            WAIT_SECS=$((RESET_EPOCH - NOW_EPOCH + 60))
            WAIT_MINS=$((WAIT_SECS / 60))
            echo "⏸️  Rate limit hit. $RESET_MSG. Sleeping ${WAIT_MINS} minutes until reset..."
            sleep "$WAIT_SECS"
        else
            echo "⏸️  Rate limit hit. Couldn't parse reset time. Sleeping 30 minutes..."
            sleep 1800
        fi
        continue
    elif [ "$EXIT_CODE" -ne 0 ]; then
        echo "⚠️  Claude exited with code $EXIT_CODE. Check $LOG_FILE"
        echo "   Waiting 30 seconds before retry..."
        sleep 30
        continue
    fi

    # ── Auto-commit on task completion ───────────────────────────────────

    TASKS_AFTER=$(grep -c -- '- \[x\]' "$PROJECT_DIR/implementation-plan.md" 2>/dev/null || echo 0)

    if [ "$TASKS_AFTER" -gt "$TASKS_BEFORE" ]; then
        COMPLETED_TASK=$(diff <(git show HEAD:implementation-plan.md 2>/dev/null || echo "") implementation-plan.md \
            | grep '^\+[^+].*\[x\]' | head -1)
        # Remove diff prefix and checkbox with optional indentation
        COMPLETED_TASK="${COMPLETED_TASK#+}"
        COMPLETED_TASK="${COMPLETED_TASK#"${COMPLETED_TASK%%[![:space:]]*}"}"
        COMPLETED_TASK="${COMPLETED_TASK#- \[x\] }"
        COMPLETED_TASK="${COMPLETED_TASK:-task $ITERATION}"

        git add -A
        git commit -m "ralph #${ITERATION}: ${COMPLETED_TASK}" --no-verify
        echo "📝 Committed: ralph #${ITERATION}: ${COMPLETED_TASK}"
    else
        echo "⏭️  No new task completed — skipping commit."
    fi

    sleep 5
    echo ""
done

# ── Finish ───────────────────────────────────────────────────────────────────

echo ""
echo "🏁 Ralph loop finished after $ITERATION iterations."
echo "   Check $LOG_DIR for full logs."
if [ -f "$PROJECT_DIR/STUCK.md" ]; then
    echo "   📋 STUCK.md has details on unresolved tasks."
fi
