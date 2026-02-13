#!/bin/bash

# ===================================================
# 🛡️  RALPH LOOP: HARDENED EXECUTOR
# ===================================================

CONTEXT="$1"
MANUAL_DIR="$2"
LOG_FILE="ralph_session.log"

# 1. ROBUST PATH RESOLUTION
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CWD="$(pwd)"

POSSIBLE_CONFIGS=(
    "$CWD/config/ralph-strict.json"
    "$(dirname "$SCRIPT_DIR")/config/ralph-strict.json"
    "$SCRIPT_DIR/config/ralph-strict.json"
)

STRICT_CONFIG=""
for config in "${POSSIBLE_CONFIGS[@]}"; do
    if [ -f "$config" ]; then STRICT_CONFIG="$config"; break; fi
done

# 2. INPUT VALIDATION
if [ -z "$CONTEXT" ]; then echo "❌ Error: Context missing."; exit 1; fi

# 3. WORKSPACE RESOLUTION
if [ -n "$MANUAL_DIR" ]; then
    TARGET_DIR="$MANUAL_DIR"
else
    PROJECT_NAME=$(echo "$CONTEXT" | grep -iE "^(Project|Mission|Feature|Task):" | head -n 1 | cut -d: -f2 | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_*//;s/_*$//')
    [ -z "$PROJECT_NAME" ] && TARGET_DIR="ralph_mission_$(date +%Y%m%d_%H%M%S)" || TARGET_DIR="ralph_${PROJECT_NAME}"
fi
echo ">> 📂 Workspace: ./$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# 4. CONFIG INJECTION
if [ -n "$STRICT_CONFIG" ]; then
    cp "$STRICT_CONFIG" "$TARGET_DIR/claude.json"
else
    echo "❌ FATAL: Config not found."; exit 1
fi

# 5. CONTEXT FUSION
README_PATH="$TARGET_DIR/README.md"
if [ -f "$README_PATH" ]; then
    PROJECT_CONTEXT=$(cat "$README_PATH")
else
    PROJECT_CONTEXT="(New Project)"
fi

cd "$TARGET_DIR" || exit 1

# 6. GIT INIT
if [ ! -d ".git" ]; then
    git init -q
    [ ! -f ".gitignore" ] && echo -e ".DS_Store\nnode_modules/\n*.log\nclaude.json" > .gitignore
    git add .gitignore
    git commit -m "chore: init" -q
fi

# 7. START LOOP
# We use a strict "System Prompt" style to force execution.
CURRENT_PROMPT="
MISSION:
$CONTEXT

STATE (README):
$PROJECT_CONTEXT

SYSTEM INSTRUCTIONS:
1. You are Ralph (Senior Engineer).
2. You are in 'NON-INTERACTIVE EXECUTION MODE'.
3. DO NOT ask 'What would you like to do?'.
4. DO NOT ask 'Shall I proceed?'.
5. IMMEDIATELY GENERATE CODE or RUN COMMANDS to complete the next step in the README.
6. If the README is missing/empty, create it with a Todo list immediately.
7. Output your plan for step 1.
"

TURN=1

while true; do
    echo "---------------------------------------------------"
    echo ">> 🤖 Ralph (Turn $TURN)..."
    echo "---------------------------------------------------"
    echo "[TURN $TURN] PROMPT: ${CURRENT_PROMPT:0:50}..." >> "$LOG_FILE"

    RESPONSE=$(claude -p "$CURRENT_PROMPT" --dangerously-skip-permissions)
    
    echo "$RESPONSE"
    echo "---------------------------------------------------"
    echo "[TURN $TURN] RESPONSE: $RESPONSE" >> "$LOG_FILE"

    if [ -n "$(git status --porcelain)" ]; then
        echo ">> 💾 Committing..."
        git add .
        DIFF=$(git diff --cached --stat)
        MSG=$(claude -p "Commit msg for:\n$DIFF" --dangerously-skip-permissions 2>/dev/null)
        [ -z "$MSG" ] && MSG="wip: turn $TURN"
        MSG=$(echo "$MSG" | tr -d '"')
        git commit -m "$MSG" -q
        echo "   ✅ $MSG"
    fi

    echo ">> 🎤 COMMAND CENTER:"
    read -r -p ">> " USER_INPUT < /dev/tty

    if [[ "$USER_INPUT" == "x" ]]; then exit 0; fi
    # CRITICAL: If user just hits enter, we tell Ralph to KEEP GOING.
    if [[ -n "$USER_INPUT" ]]; then 
        CURRENT_PROMPT="$USER_INPUT"
    else 
        CURRENT_PROMPT="STATUS UPDATE: Previous step completed. Check README for next TODO item and EXECUTE IT IMMEDIATELY. Do not ask for permission."
    fi
    
    ((TURN++))
done
