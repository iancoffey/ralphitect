import sys
import json
import subprocess

# usage: python3 lib/grader.py <file_path> <doc_type>

def grade_document(file_path, doc_type):
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        return {"score": 0, "reasoning": "File not found."}

    # The Rubric Prompt
    prompt = f"""
    You are a Principal Engineer and strict Auditor. 
    Grade this {doc_type} on a scale of 0-100.
    
    RUBRIC:
    - 90-100: Perfect. unambiguous, technically rigorous, edge cases covered.
    - 80-89: Good. Actionable, but minor gaps.
    - <80: Fail. Vague, incomplete, or lacks technical depth.

    DOCUMENT CONTENT:
    {content[:15000]}  # Truncate to avoid context limits if massive

    OUTPUT:
    Return ONLY raw JSON in this format:
    {{
        "score": <int>,
        "reasoning": "<concise explanation of why it passed or failed>",
        "gaps": ["<specific gap 1>", "<specific gap 2>"]
    }}
    """

    # Call Claude via CLI
    # We pipe the prompt into the claude CLI and capture stdout
    try:
        result = subprocess.run(
            ['claude', '-p', prompt], 
            capture_output=True, 
            text=True, 
            timeout=60
        )
        
        # Extract JSON from potential markdown chatter
        raw_output = result.stdout
        # (Simple parser to find the JSON object)
        json_start = raw_output.find('{')
        json_end = raw_output.rfind('}') + 1
        
        if json_start == -1 or json_end == 0:
            return {"score": 0, "reasoning": "Model failed to return JSON.", "raw": raw_output}
            
        json_str = raw_output[json_start:json_end]
        return json.loads(json_str)

    except Exception as e:
        return {"score": 0, "reasoning": f"System Error: {str(e)}"}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(json.dumps({"score": 0, "reasoning": "Invalid arguments"}))
        sys.exit(1)
        
    path = sys.argv[1]
    dtype = sys.argv[2]
    
    result = grade_document(path, dtype)
    print(json.dumps(result, indent=2))
