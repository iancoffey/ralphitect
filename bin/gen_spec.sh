#!/bin/bash

# ===================================================
# 🧬 RALPH COMPILER: Docs -> Spec.json
# ===================================================

# 1. SETUP
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SCHEMA_FILE="$BASE_DIR/schemas/prd_schema.json"

# Check for Claude CLI
if ! command -v claude &> /dev/null; then
    echo "❌ Error: 'claude' command not found."
    echo "   Install it via: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

# 2. INPUT VALIDATION
if [ -z "$1" ]; then
    echo "❌ Usage: $0 <target_directory>"
    echo "   Example: $0 specs/webhook"
    exit 1
fi

TARGET_DIR="$1"
TARGET_DIR=${TARGET_DIR%/} # Strip trailing slash

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: Directory '$TARGET_DIR' not found."
    exit 1
fi

PRD_FILE="$TARGET_DIR/prd.md"
DESIGN_FILE="$TARGET_DIR/design.md"
OUTPUT_FILE="$TARGET_DIR/spec.json"

# 3. EXISTENCE CHECK
MISSING=0
if [ ! -f "$PRD_FILE" ]; then echo "❌ Missing: prd.md"; MISSING=1; fi
if [ ! -f "$DESIGN_FILE" ]; then echo "❌ Missing: design.md"; MISSING=1; fi

if [ $MISSING -eq 1 ]; then
    echo "   (This tool requires manual docs first. Write them, then compile.)"
    exit 1
fi

echo ">> 🧐 Reading docs from $TARGET_DIR..."
PRD_CONTENT=$(cat "$PRD_FILE")
DESIGN_CONTENT=$(cat "$DESIGN_FILE")

# 4. THE AUDITOR PROMPT
echo ">> 🧠 Auditing rigor and compiling spec..."

PROMPT_FILE="/tmp/ralph_prompt.txt"
cat <<EOF > "$PROMPT_FILE"
You are a Principal Engineer acting as a Gatekeeper.
Your Task: Review the provided PRD and Design Doc.

INPUT DATA:
---
PRD:
$PRD_CONTENT
---
DESIGN DOC:
$DESIGN_CONTENT
---

REQUIRED OUTPUT SCHEMA (If Approved):
$(cat "$SCHEMA_FILE")

INSTRUCTIONS:
1. **Analyze for Rigor**: Do the stories have acceptance criteria? Does the design handle failure modes? Is the tech stack explicit?
2. **DECISION**:
   - IF VAGUE/WEAK: Return a JSON object: { "status": "REJECT", "feedback": "<bulleted list of what is missing>" }
   - IF SOLID: Return a JSON object: { "status": "APPROVED", "spec": <The Valid JSON Object matching the schema above> }
3. **Constraint**: Output ONLY raw JSON. No markdown.
EOF

# Send to Claude and capture output
# We use -p to pipe the file content
RESPONSE=$(claude -p "$(cat $PROMPT_FILE)")

# 5. PARSE RESPONSE WITH PYTHON
# We write the python parser to a temp file to avoid bash quoting errors
PARSER_SCRIPT="/tmp/ralph_parser.py"
cat <<EOF > "$PARSER_SCRIPT"
import sys, json

try:
    # Read stdin (the Claude response)
    raw = sys.stdin.read()
    # Attempt to find JSON start/end if there is chatter
    start = raw.find('{')
    end = raw.rfind('}') + 1
    if start == -1:
        raise ValueError("No JSON found")
    data = json.loads(raw[start:end])
    if data.get('status') == 'REJECT':
        print('REJECTED')
        print(data.get('feedback'))
        sys.exit(1)
    elif data.get('status') == 'APPROVED':
        # Write the spec to the target file
        with open('$OUTPUT_FILE', 'w') as f:
            json.dump(data['spec'], f, indent=2)
        print('APPROVED')
    else:
        print('UNKNOWN_RESPONSE')
        print(raw)
        sys.exit(1)
except Exception as e:
    print('ERROR_PARSING')
    print(str(e))
    # Print a snippet of raw output to help debug
    print('Raw Output Snippet:', raw[:100])
    sys.exit(1)
EOF

# Run the parser, piping the response into it
echo "$RESPONSE" | python3 "$PARSER_SCRIPT" > /tmp/ralph_compile_result 2>&1
RESULT_CODE=$?
OUTPUT_LOG=$(cat /tmp/ralph_compile_result)

# 6. HANDLE RESULT
if [[ "$OUTPUT_LOG" == *"REJECTED"* ]]; then
    FEEDBACK=$(echo "$OUTPUT_LOG" | sed '1d') # Remove the first line (REJECTED)
    echo "=================================================="
    echo "🛑 GATEKEEPER REJECTION: Docs insufficient."
    echo "=================================================="
    echo "$FEEDBACK"
    echo "=================================================="
    echo "Action: Fix the markdown files and run this again."
    exit 1

elif [[ "$OUTPUT_LOG" == *"APPROVED"* ]]; then
    echo "=================================================="
    echo "✅ SUCCESS: Docs approved."
    echo "=================================================="
    echo ">> 💾 Compiled to: $OUTPUT_FILE"
    
    if command -v jq >/dev/null; then
        echo ">> Preview:"
        jq -r '"   Task: \(.feature_name)\n   Obj:  \(.objective)"' "$OUTPUT_FILE"
    fi
    exit 0
else
    echo "❌ FATAL: Compiler Error."
    echo "$OUTPUT_LOG"
    exit 1
fi
