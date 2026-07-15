# models/local.py
# Local Ollama api
import warnings
# Silence both the Python 3.9 EOL warnings and the Google SDK text-parts warnings
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

import urllib.request
import json
import os
import sys
from pathlib import Path

def load_config(filepath):
    config = {}
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            
            # Ignore empty lines or comments
            if not line or line.startswith("#"):
                continue
                
            # Split key and value on the first "=" sign
            if "=" in line:
                key, val = line.split("=", 1)
                
                # Strip spaces and enclosing quotes from keys and values
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                
                config[key] = val
    return config
    
def main():

    # 2. Get vars from your .conf 
    raw_path = sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent
    path = Path(raw_path)
    
    config_file = path / "local.conf"
    config = load_config(config_file)

    model_name = config.get("MODEL_NAME", "qwen-fixed:latest")
    model_url = config.get("MODEL_BASE_URL", "http://localhost:11434")
    ctx_size = int(config.get("MODEL_CONTEXT_SIZE", 4096))
    timeout = int(config.get("MODEL_RETRY_TIMEOUT", 10))
      
    # 1. Capture the prompt from STDIN
    try:
        prompt = sys.stdin.read()
    except Exception as e:
        print(f'{{"error": "Read STDIN error: {e}"}}')
        sys.exit(1)
        

    # 2. Build the OLLAMA payload 
    payload = {
        "model": model_name,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "options": {
            "num_ctx": ctx_size
        }
    }
    
    data = json.dumps(payload).encode("utf-8")

    # 3. Set up the Request (Local needs no API Key)
    # Note: Adding /api/generate to the URL if it's just the base IP
    full_url = f"{model_url.rstrip('/')}/api/generate"
    req = urllib.request.Request(full_url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    # 4. Execute
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            # 1. Read the raw bytes from urllib and decode to a string
            raw_response = response.read().decode("utf-8")
            
            # 2. Parse the string into a Python dictionary
            response_data = json.loads(raw_response)

        # 3. Check if Ollama returned an API-level error safely
        if "error" in response_data:
            err = response_data["error"]
            error_msg = err.get("message", "Unknown API Error") if isinstance(err, dict) else str(err)
            print(json.dumps({"error": error_msg}))
            sys.exit(0)

        # 4. Extract completion text (Ollama uses "response", NOT "choices")
        if "response" in response_data and response_data["response"]:
            raw_content = response_data["response"]
            
            # Try to parse the model's inner content as JSON
            try:
                content_json = json.loads(raw_content)
                
                # Build our standardized output payload
                output = {
                    "command": content_json.get("command", ""),
                    "explanation": content_json.get("explanation", ""),
                    "new_fact": content_json.get("new_fact", ""),
                    "task_completed": content_json.get("task_completed", ""),
                    "goal_completed": content_json.get("goal_completed", ""),
                    "context": response_data.get("context", "")
                }
            except json.JSONDecodeError:
                # Fallback: If the model didn't reply in clean JSON, 
                # treat the entire raw string as the explanation
                output = {
                    "command": "",
                    "explanation": raw_content,
                    "new_fact": "",
                    "task_completed": "",
                    "goal_completed": "",
                    "context": ""
                }
            
            # Print the final flat JSON object for Bash to read
            print(json.dumps(output))

        else:
            print(json.dumps({"error": "Empty response from model"}))
            
    except Exception as e:
        # Return a JSON error so your 'jq' check in Bash catches it
        print(json.dumps({"error": str(e)}))
        sys.exit(0)

if __name__ == "__main__":
    main()