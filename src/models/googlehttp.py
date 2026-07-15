# models/geminiflash.py
# Remote Generative Google Flash api
import logging
import warnings
import urllib.request
import urllib.error
import json
import os
import sys
import time
from pathlib import Path

# 1. Silence Python's built-in deprecation warnings
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

# 2. Force Google's package loggers to ONLY show CRITICAL errors (hiding WARNINGS)
logging.getLogger("google").setLevel(logging.CRITICAL)

def load_config(filepath):
    config = {}
    if not os.path.exists(filepath):
        return config
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
    start_time = time.time()
    
    # 1. Get vars from config
    raw_path = sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent
    path = Path(raw_path)
    
    config_file = path / "googlehttp.conf"
    config = load_config(config_file)
    
    api_key = config.get("API_KEY", "")
    model_name = config.get("MODEL_NAME", "gemini-2.5-flash") # Updated fallback to stable
    timeout = int(config.get("MODEL_RETRY_TIMEOUT", 120))
    max_rate_retries = int(config.get("MAX_RATE_LIMIT_RETRIES", 5))

    # 2. Capture the prompt from stdin
    try:
        if sys.stdin.isatty():
            print(json.dumps({"error": "No input provided via stdin"}))
            sys.exit(1)
        prompt = sys.stdin.read()
    except Exception as e:
        print(json.dumps({"error": f"Read error: {e}"}))
        sys.exit(1)

    if not api_key or not model_name:
        print(json.dumps({"error": f"Missing Config: API_KEY={bool(api_key)}, MODEL={model_name}"}))
        sys.exit(1)
        
    # 3. Build URL & Payload
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"response_mime_type": "application/json"}
    }
    data = json.dumps(payload).encode("utf-8")
    rate_retries = 0
    raw_content = ""

    # 4. Request and Retry Loop
    while True:
        req = urllib.request.Request(url, data=data, method="POST")
        req.add_header("Content-Type", "application/json")

        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                raw_response = response.read().decode("utf-8")
                response_data = json.loads(raw_response)
                # print(f"RESPONSE:{response_data}")
                
                # Extract the generation text safely
                candidates = response_data.get("candidates", [])
                if candidates:
                    parts = candidates[0].get("content", {}).get("parts", [])
                    if parts:
                        raw_content = parts[0].get("text", "")
                break # Success! Break out of loop.

        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            
            # CASE: 503 Service Unavailable (Spike)
            if e.code == 503:
                time.sleep(timeout)
                continue
                
            # CASE: 429 Rate Limit / Quota Exceeded
            elif e.code == 429:
                # Case: Hard Quota Exceeded
                if "GenerateRequestsPerDayPerProjectPerModel" in err_body:
                    print(json.dumps({"error": "Daily project quota exhausted."}))
                    sys.exit(0) # Standard exit so Bash receives JSON error cleanly
                
                # Case: Rate limit spike
                rate_retries += 1
                if rate_retries > max_rate_retries:
                    print(json.dumps({"error": "Rate limit retries exhausted."}))
                    sys.exit(0)
                
                # Standard wait time back-off (e.g., 15 seconds)
                time.sleep(15)
                continue
            
            # CASE: Hard fatal HTTP errors (e.g., 400 Bad Request, 403 Invalid Key)
            else:
                print(json.dumps({"error": f"HTTP {e.code}", "details": err_body}))
                sys.exit(0)

        except Exception as e:
            # Catch network dropouts or timeouts
            print(json.dumps({"error": str(e)}))
            sys.exit(0)

    # 5. Extract and Format to Flat Standard JSON Structure
    output = {
        "command": "",
        "explanation": "",
        "new_fact": "",
        "task_completed": "",
        "goal_completed": "",
        "context": ""
    }

    if raw_content:
        try:
            # Parse inner generated text as JSON since we asked for response_mime_type
            content_json = json.loads(raw_content)
            output["command"] = content_json.get("command", "")
            output["explanation"] = content_json.get("explanation", "")
            output["new_fact"] = content_json.get("new_fact", "")
            output["task_completed"] = content_json.get("task_completed", "")
            output["goal_completed"] = content_json.get("goal_completed", "")
        except json.JSONDecodeError:
            # Fallback in case Gemini returns plain text instead of JSON
            output["explanation"] = raw_content

    # Calculate total duration in nanoseconds so Bash bc calculation matches local.py
    duration_ns = int((time.time() - start_time) * 1_000_000_000)
    output["total_duration"] = duration_ns

    # Output flat JSON to STDOUT
    print(json.dumps(output))

if __name__ == "__main__":
    main()