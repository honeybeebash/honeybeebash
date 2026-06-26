# models/geminiflash.py
# Remote Generative Google Flash api
import logging
import warnings

# 1. Silence Python's built-in deprecation warnings
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

# 2. Force Google's package loggers to ONLY show CRITICAL errors (hiding WARNINGS)
logging.getLogger("google").setLevel(logging.CRITICAL)
logging.getLogger("google.genai").setLevel(logging.CRITICAL)

import urllib.request
import json
import os
import sys

def main():
    # 1. Capture the prompt
    try:
        # Use a timeout or check if stdin is empty
        if sys.stdin.isatty():
            print(json.dumps({"error": "No input provided via stdin"}))
            sys.exit(1)
        prompt = sys.stdin.read()
    except Exception as e:
        print(json.dumps({"error": f"Read error: {e}"}))
        sys.exit(1)

    # 2. Extract Environment Variables
    api_key = os.environ.get("GEMINI_API_KEY")
    # Use the name from your .conf
    model_name = os.environ.get("SELECTED_MODEL_NAME")
    timeout = int(os.environ.get("MAX_TIMEOUT", 60))

    if not api_key or not model_name:
        print(json.dumps({"error": f"Missing Config: API_KEY={bool(api_key)}, MODEL={model_name}"}))
        sys.exit(1)

    # 3. Build URL
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"response_mime_type": "application/json"}
    }
    
    try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, method="POST")
        req.add_header("Content-Type", "application/json")

        with urllib.request.urlopen(req, timeout=timeout) as response:
            print(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        # This will catch 400/403/500 errors and show the API's reason
        err_body = e.read().decode("utf-8")
        print(json.dumps({"error": f"HTTP {e.code}", "details": err_body}))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()