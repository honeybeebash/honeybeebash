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

def main():
    # 1. Capture the prompt from STDIN
    try:
        prompt = sys.stdin.read()
    except Exception as e:
        print(f'{{"error": "Read STDIN error: {e}"}}')
        sys.exit(1)

    # 2. Get vars from your .conf (via Bash export)
    # We use the names from your local.conf
    model_name = os.environ.get("SELECTED_MODEL_NAME", "qwen-fixed:latest")
    model_url = os.environ.get("MODEL_BASE_URL", "http://localhost:11434")
    ctx_size = int(os.environ.get("SELECTED_CONTEXT_SIZE", 4096))
    timeout = int(os.environ.get("MAX_TIMEOUT", 120))

    # 3. Build the OLLAMA payload (NOT Gemini)
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

    # 4. Set up the Request (Ollama usually needs no API Key)
    # Note: Adding /api/generate to the URL if it's just the base IP
    full_url = f"{model_url.rstrip('/')}/api/generate"
    req = urllib.request.Request(full_url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    # 5. Execute
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            print(response.read().decode("utf-8"))
    except Exception as e:
        # Return a JSON error so your 'jq' check in Bash catches it
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()