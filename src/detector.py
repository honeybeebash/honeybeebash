# HoneyBeeBase command scanner
# detector.py
# Command security
#
# Weighted Random Forest / Cost-Sensitive Learning
# Weighted Supervised Learning Pipeline using Bag-of-Words.
import os
import sys
import signal

# --- COLOR & ICON DEFINITIONS ---
# Standard ANSI Colors (Work in most environments)
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"

exit_requested = False
def handle_sigint(sig, frame):
    global exit_requested
    exit_requested = True
    print(f"\n{YELLOW}[!] Interrupt received. Finishing current operation...{RESET}")

signal.signal(signal.SIGINT, handle_sigint)

try:
    import joblib
    import pandas as pd
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.ensemble import RandomForestClassifier
except ImportError as e:
    print(f"ERROR: Missing dependency ({e.name}).")
    print("Please run: pip install joblib pandas scikit-learn")
    sys.exit(0) # Exit gracefully

# --- CONFIGURATION ---
# RESTRICTIVE (Whitelist): "If I don't know you, you're not coming in."
# PERMISSIVE (Blacklist): "You can come in unless I know you're a troublemaker."
SECURITY_POLICY = "PERMISSIVE" 
# The default, can be overruled by third parameter
MODEL_FILE = ""
VECTORIZER_FILE = ""
DATASET_FILE = ""

# Detect if we are in a raw terminal (linux console) or a modern one
# The 'linux' term usually refers to the raw TTY/System console.
if os.environ.get('TERM') == 'linux':
    # RAW TERMINAL: Use text-based markers for safety
    ICON_SAFE = "[+]"
    ICON_WARN = "[!]"
    ICON_LOCK = "[?]"
    ICON_DANGER = "[X]"
else:
    # MODERN TERMINAL: Use the high-definition icons
    ICON_SAFE = "💎"
    ICON_WARN = "⚠️"
    ICON_LOCK = "🔒"
    ICON_DANGER = "🐝" # A literal honeybee acting on threats

def train_and_save(dataset_path, model_path, vectorizer_path):
    # print(f"DEBUG:{dataset_path}:{model_path}:{vectorizer_path}")
    if not os.path.exists(dataset_path):
        sys.exit(102)

    df = pd.read_csv(dataset_path)

    # Drop rows that are missing labels or commands
    df = df.dropna(subset=['command', 'label'])
    # Fill missing weights with 1.0
    df['weight'] = df['weight'].fillna(1.0)

    # If weight column doesn't exist (migration), default to 1
    if 'weight' not in df.columns:
        df['weight'] = 1

    vectorizer = TfidfVectorizer()
    X = vectorizer.fit_transform(df['command'].values.astype('U'))
    
    #  We pass the weights here
    clf = RandomForestClassifier(n_estimators=100)
    clf.fit(X, df['label'], sample_weight=df['weight']) 

    # --- CRITICAL SECTION - Disable interupt ---
    old_handler = signal.getsignal(signal.SIGINT)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    
    joblib.dump(clf, model_path)
    joblib.dump(vectorizer, vectorizer_path)
    
    signal.signal(signal.SIGINT, old_handler) # Restore interrupt
    # -------------------------------------------
        
    return clf, vectorizer



# --- EXECUTION ---
if __name__ == "__main__":

    if len(sys.argv) < 3:
        # print("Usage: python3 malicious_detector.py <job_name> <command> <verbose>")
        sys.exit(100)

    job_dir = sys.argv[1]
    input_cmd = " ".join(sys.argv[2:])
    automation_mode = " ".join(sys.argv[3:])
    
    try:
        verbose_level = int(sys.argv[4])
    except (IndexError, ValueError):
        # Default to 0 if the argument is missing or not a number
        verbose_level = 0

    if not job_dir:
        sys.exit(101)
    if not input_cmd:
        sys.exit(101)

    # Local paths
    m_path = f"{job_dir}/cache/model.pkl"
    v_path = f"{job_dir}/cache/vectorizer.pkl"
    d_path = f"{job_dir}/cache/dataset.csv"
    
    # print(f"DEBUG:{m_path}:{v_path}:{d_path}")

    # --- INITIALIZATION ---
    if os.path.exists(m_path) and os.path.exists(v_path):
        clf = joblib.load(m_path)
        vectorizer = joblib.load(v_path)
    else:
        # Pass the paths into the function!
        clf, vectorizer = train_and_save(d_path, m_path, v_path)

    v = vectorizer.transform([input_cmd])
    probabilities = clf.predict_proba(v)[0]
    
    malicious_prob = probabilities[1]
    safe_prob = probabilities[0]

    if automation_mode == "RESTRICTIVE":
        if safe_prob < 1.0:
            if verbose_level > 0:
                print(f"{RED}{ICON_WARN} WARNING: Unrecognized bait! Policy is RESTRICTIVE. ({safe_prob:.2f}){RESET}\n")
            sys.exit(1)
        else:
            if verbose_level > 1:
                print(f"{GREEN}{ICON_SAFE} PRISTINE: Pearl verified. ({safe_prob:.2f}){RESET}\n")
            sys.exit(0)

    else: # PERMISSIVE
        if malicious_prob > 0.80:
            if verbose_level > 0:
                print(f"{RED}{ICON_DANGER} DANGER: That's a trap! (Threat: {malicious_prob:.2f}){RESET}\n")
            sys.exit(1)
        elif malicious_prob < 0.10:
            if verbose_level > 0:
                print(f"{GREEN}{ICON_SAFE} VANTAGE: Clear signature. (Variance: {malicious_prob:.2%}){RESET}\n")
            sys.exit(9)
        elif malicious_prob == 0:
            if verbose_level > 1:
                print(f"{GREEN}{ICON_SAFE} CLEAR WATER: Smooth sailing. ({safe_prob:.2f}){RESET}\n")
            sys.exit(10)
        else:
            if verbose_level > 1:
                print(f"{YELLOW}{ICON_LOCK} CLOUDY: Smells fishy, but passing... (Threat: {malicious_prob:.2f}){RESET}\n")
            sys.exit(0)