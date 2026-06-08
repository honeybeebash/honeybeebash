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
from google import genai

def main():
    # 1. Read the dynamic prompt from Bash pipe
    try:
        if sys.stdin.isatty():
            # If no pipe is detected, exit
            sys.exit(0)
        prompt = sys.stdin.read()
    except Exception:
        sys.exit(1)

    # 2. Initialize Client (uses GEMINI_API_KEY from os.environ)
    try:
        api_key = os.environ.get("GEMINI_API_KEY")
        model_name = os.environ.get("SELECTED_MODEL_NAME", "gemini-3-flash-preview")
        
        client = genai.Client(api_key=api_key)

        # 3. Generate Content
        response = client.models.generate_content(
            model=model_name, 
            contents=prompt
        )
        
        # 4. Output only the text for Bash to capture
        if response.text:
            print(response.text)
            
    except Exception as e:
        # Print error to stderr so it doesn't pollute the RESPONSE variable
        print(f"SDK Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()