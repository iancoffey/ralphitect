#!/bin/bash

# ===================================================
# 🧬 RALPH COMPILER: Docs -> Spec.json
# ===================================================

# 1. SETUP
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SCHEMA_FILE="$BASE_DIR/schemas/prd_schema.json"

# Check dependencies
if ! command -v claude &> /dev/null; then
    echo "❌ Error: 'claude' CLI not found. (npm install -g @anthropic-ai/claude-code)"
    exit 1
fi

# 2. ARGUMENT PARSING (Support --force flag)
FORCE_MODE=0
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE_MODE=1
      shift 
      ;;
    *)
      POSITIONAL_ARGS+=("$1") 
      shift 
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional args
TARGET_DIR="$1"

# 3. BASIC VALIDATION
if [ -z "$TARGET_DIR" ]; then
    echo "❌ Usage: $0 <target_directory> [--force]"
    echo "   Example: $0 specs/webhook --force"
    exit 1
fi

TARGET_DIR=${TARGET_DIR%/} # Strip trailing slash

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: Directory '$TARGET_DIR' not found."
    exit 1
fi

PRD_FILE="$TARGET_DIR/prd.md"
DESIGN_FILE="$TARGET_DIR/design.md"
OUTPUT_FILE="$TARGET_DIR/spec.json"

# Existence Check
MISSING=0
if [ ! -f "$PRD_FILE" ]; then echo "❌ Missing: prd.md"; MISSING=1; fi
if [ ! -f "$DESIGN_FILE" ]; then echo "❌ Missing: design.md"; MISSING=1; fi

if [ $MISSING -eq 1 ]; then
    echo "   (Required files missing. Cannot compile.)"
    exit 1
fi

# 4. CONTEXT LOADING
echo ">> 🧐 Reading docs from $TARGET_DIR..."
PRD_CONTENT=$(cat "$PRD_FILE")
DESIGN_CONTENT=$(cat "$DESIGN_FILE")

# 5. DYNAMIC PROMPT GENERATION
if [ $FORCE_MODE -eq 1 ]; then
    echo ">> ⚠️  FORCE MODE ACTIVE: Skipping strict validation."
    echo ">> 🧠 Autocompleting gaps using industry standards..."
    
    # THE "FIXER" PERSONA
    INSTRUCTIONS="
    MODE: FORCE_COMPLETION
    1. **IGNORE missing details**: Do not reject the docs.
    2. **AUTO-FILL Gaps**:
       - If retry codes are missing, insert standard ones (408, 429, 500, 502, 503, 504).
       - If the Design cuts off, extrapolate a standard architecture (e.g. Postgres + Worker Pool).
       - If specific metrics are missing, add standard RED metrics (Rate, Errors, Duration).
    3. **OUTPUT**: You MUST return { \"status\": \"APPROVED\", \"spec\": ... }
    "
else
    echo ">> 🧠 Auditing rigor (Strict Mode)..."
    
    # THE "GATEKEEPER" PERSONA
    INSTRUCTIONS="
    MODE: STRICT_AUDIT
    1. **Analyze for Rigor**: Check for failure modes, specific error codes, and explicit tech stacks.
    2. **DECISION**:
       - IF VAGUE: Return { \"status\": \"REJECT\", \"feedback\": \"<bulleted list of gaps>\" }
       - IF SOLID: Return { \"status\": \"APPROVED\", \"spec\": ... }
    "
fi

PROMPT_FILE="/tmp/ralph_prompt.txt"
cat <<EOF > "$PROMPT_FILE"
You are a Principal Engineer.
Your Task: compile the provided PRD and Design Doc into a JSON Specification.

INPUT DATA:
---
PRD:
$PRD_CONTENT
---
DESIGN DOC:
$DESIGN_CONTENT
---

REQUIRED OUTPUT SCHEMA:
$(cat "$SCHEMA_FILE")

INSTRUCTIONS:
$INSTRUCTIONS

CONSTRAINT: Output ONLY raw JSON. No markdown.
EOF

# 6. EXECUTE CLAUDE
RESPONSE=$(claude -p "$(cat $PROMPT_FILE)")

# 7. PARSE OUTPUT (Python)
PARSER_SCRIPT="/tmp/ralph_parser.py"
cat <<EOF > "$PARSER_SCRIPT"
import sys, json

try:
    raw = sys.stdin.read()
    start = raw.find('{')
    end = raw.rfind('}') + 1
    if start == -1: raise ValueError("No JSON found")
    
    data = json.loads(raw[start:end])
    
    if data.get('status') == 'REJECT':
        print('REJECTED')
        print(data.get('feedback'))
        sys.exit(1)
    elif data.get('status') == 'APPROVED':
        with open('$OUTPUT_FILE', 'w') as f:
            json.dump(data['spec'], f, indent=2)
        print('APPROVED')
    else:
        print('UNKNOWN_RESPONSE')
        print(raw[:200]) # Debug snippet
        sys.exit(1)
        
except Exception as e:
    print('ERROR_PARSING')
    print(str(e))
    sys.exit(1)
EOF

echo "$RESPONSE" | python3 "$PARSER_SCRIPT" > /tmp/ralph_compile_result 2>&1
RESULT_CODE=$?
OUTPUT_LOG=$(cat /tmp/ralph_compile_result)

# 8. FINAL REPORT
if [[ "$OUTPUT_LOG" == *"REJECTED"* ]]; then
    FEEDBACK=$(echo "$OUTPUT_LOG" | sed '1d')
    echo "=================================================="
    echo "🛑 REJECTED (Strict Mode)"
    echo "=================================================="
    echo "$FEEDBACK"
    echo "=================================================="
    echo "💡 Tip: Use --force to auto-fill these gaps."
    exit 1

elif [[ "$OUTPUT_LOG" == *"APPROVED"* ]]; then
    echo "=================================================="
    if [ $FORCE_MODE -eq 1 ]; then
        echo "✅ SUCCESS (Force Mode)"
        echo "   (Gaps were auto-filled with best-guess standards)"
    else
        echo "✅ SUCCESS (Docs Approved)"
    fi
    echo "=================================================="
    echo ">> 💾 Compiled to: $OUTPUT_FILE"
    exit 0
else
    echo "❌ FATAL: Compiler Error."
    echo "$OUTPUT_LOG"
    exit 1
fi
