# models/openrouter.py
# The OpenRouter API Integration
import warnings
import sys
import os
import requests
import json
import time
from pathlib import Path

# Silence Python's built-in deprecation warnings
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

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

    # 1. Load Configurations
    raw_path = sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent
    path = Path(raw_path)
    
    config_file = path / "openrouter.conf"
    config = load_config(config_file)

    # Grab variables from config, falling back to environment variables or defaults
    api_key = config.get("API_KEY") or os.environ.get("API_KEY", "")
    model_url = config.get("MODEL_BASE_URL") or os.environ.get("MODEL_BASE_URL", "https://openrouter.ai/api/v1/chat/completions")
    model_name = config.get("MODEL_NAME") or os.environ.get("MODEL_NAME", "google/gemini-2.5-flash")
    site_url = config.get("SITE_URL") or os.environ.get("SITE_URL", "")
    site_title = config.get("SITE_TITLE") or os.environ.get("SITE_TITLE", "")
    timeout = int(config.get("MODEL_RETRY_TIMEOUT", 30))

    # 2. Read the dynamic prompt from Bash pipe
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

    raw_content = ""

    # 3. Initialize connection and call OpenRouter API
    try:
        response = requests.post(
            url=model_url,
            timeout=timeout,
            headers={
                "Authorization": f"Bearer {api_key}",
                "HTTP-Referer": site_url,          # Optional metadata
                "X-OpenRouter-Title": site_title,   # Optional metadata
                "Content-Type": "application/json"  # Ensure API knows JSON is coming
            },
            data=json.dumps({
                "model": model_name,
                "response_format": {"type": "json_object"}, # Ask model to output JSON
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            })
        )
        
        # Raise an exception if we got an HTTP error status
        response.raise_for_status()
        response_data = response.json()
        
        # Parse the standard OpenAI chat response structure
        if "choices" in response_data and len(response_data["choices"]) > 0:
            raw_content = response_data["choices"][0]["message"]["content"]
        else:
            print(json.dumps({"error": f"Invalid response shape: {response_data}"}))
            sys.exit(0)
            
    except Exception as e:
        # Format connection / HTTP errors cleanly for Bash
        print(json.dumps({"error": f"Connection / HTTP Error: {str(e)}"}))
        sys.exit(0)

    # 4. Format to flat standard JSON structure
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
            # Parse inner generated text as JSON since we asked for a json_object
            content_json = json.loads(raw_content)
            output["command"] = content_json.get("command", "")
            output["explanation"] = content_json.get("explanation", "")
            output["new_fact"] = content_json.get("new_fact", "")
            output["task_completed"] = content_json.get("task_completed", "")
            output["goal_completed"] = content_json.get("goal_completed", "")
        except json.JSONDecodeError:
            # Fallback in case OpenRouter returns plain text instead of JSON
            output["explanation"] = raw_content

    # Calculate total duration in nanoseconds for request_model()'s `bc` calculation
    duration_ns = int((time.time() - start_time) * 1_000_000_000)
    output["total_duration"] = duration_ns

    # Print the clean JSON back to Bash
    print(json.dumps(output))

if __name__ == "__main__":
    main()