# models/googleapi.py
# The google gemini AI API 
# Requires: pip install -q -U google-genai
import logging
import warnings

# 1. Silence Python's built-in deprecation warnings
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

# 2. Force Google's package loggers to ONLY show CRITICAL errors (hiding WARNINGS)
logging.getLogger("google").setLevel(logging.CRITICAL)
logging.getLogger("google.genai").setLevel(logging.CRITICAL)

import sys
import os
import json
import time
from pathlib import Path
from google import genai
from google.genai import types
from google.genai.errors import APIError

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
    raw_path = sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent
    path = Path(raw_path)
    
    config_file = path / "googleapi.conf"
    config = load_config(config_file)

    api_key = config.get("API_KEY", "")
    model_name = config.get("MODEL_NAME", "gemini-2.5-flash")
    timeout_sec = int(config.get("MODEL_RETRY_TIMEOUT", 10))  # Default wait for 503/Spikes
    
    # Retry Limit (Server Busy / High Demand)
    max_503_retries = 5 
    max_rate_retries = 5 

    # 1. Read the dynamic prompt from Bash pipe
    try:
        if sys.stdin.isatty():
            print(json.dumps({"error": "No input provided via stdin"}))
            sys.exit(0)
        prompt = sys.stdin.read()
    except Exception as e:
        print(json.dumps({"error": f"Stdin read error: {e}"}))
        sys.exit(0)

    if not api_key:
        print(json.dumps({"error": "Missing API_KEY in config file."}))
        sys.exit(0)

    # 2. Initialize Client with explicit Timeout Settings (in milliseconds)
    try:
        client_timeout_ms = timeout_sec * 1000
        client = genai.Client(
            api_key=api_key,
            http_options=types.HttpOptions(timeout=client_timeout_ms)
        )
    except Exception as e:
        print(json.dumps({"error": f"Initialization Error: {e}"}))
        sys.exit(0)

    # 3. Request JSON formatting so output matches what your Bash jq expectations need
    config_options = types.GenerateContentConfig(
        response_mime_type="application/json"
    )

    rate_retries = 0
    busy_retries = 0
    raw_content = ""

    # 4. Resilient Request & Retry Loop
    while True:
        try:
            # Generate Content
            response = client.models.generate_content(
                model=model_name, 
                contents=prompt,
                config=config_options
            )
            raw_content = response.text if response.text else ""
            break # Success! Exit loop

        except APIError as e:
            err_code = getattr(e, "code", 0)
            err_msg = getattr(e, "message", str(e))
            
            # CASE: 503 Server Busy / Service Unavailable Spike / High Demand
            if err_code == 503 or "high demand" in err_msg.lower():
                busy_retries += 1
                if busy_retries > max_503_retries:
                    print(json.dumps({"error": "Server busy (503 / High Demand) retries exhausted. Loop terminated."}))
                    sys.exit(0)
                
                # Sleep and try again
                time.sleep(timeout_sec)
                continue
                
            # CASE: 429 Rate Limit / Quota Exceeded
            elif err_code == 429 or "RESOURCE_EXHAUSTED" in str(e):
                # Subcase: Hard Quota exhausted
                if "GenerateRequestsPerDayPerProjectPerModel" in err_msg:
                    print(json.dumps({"error": "Daily project quota exhausted. Loop terminated."}))
                    sys.exit(0)
                
                # Subcase: Standard Rate Limit Spikes
                rate_retries += 1
                if rate_retries > max_rate_retries:
                    print(json.dumps({"error": "Rate limit retries exhausted."}))
                    sys.exit(0)
                
                # Wait 15 seconds before retrying
                time.sleep(15)
                continue
            
            # CASE: Other fatal API errors (e.g., 400 Bad Request, 403 Invalid API Key)
            else:
                print(json.dumps({"error": f"Gemini API Fatal Error: HTTP {err_code} - {err_msg}"}))
                sys.exit(0)

        except Exception as e:
            # Catch network dropouts, socket timeouts, or other client library bugs
            print(json.dumps({"error": f"Network/SDK Error: {str(e)}"}))
            sys.exit(0)

    # 5. Extract values cleanly & format identical flat JSON to standard stdout 
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
            content_json = json.loads(raw_content)
            output["command"] = content_json.get("command", "")
            output["explanation"] = content_json.get("explanation", "")
            output["new_fact"] = content_json.get("new_fact", "")
            output["task_completed"] = content_json.get("task_completed", "")
            output["goal_completed"] = content_json.get("goal_completed", "")
        except json.JSONDecodeError:
            # Fallback in case raw text gets outputted
            output["explanation"] = raw_content

    # Include total duration in nanoseconds so request_model()'s `bc` calculation functions
    duration_ns = int((time.time() - start_time) * 1_000_000_000)
    output["total_duration"] = duration_ns

    # Output flat JSON to STDOUT
    print(json.dumps(output))

if __name__ == "__main__":
    main()