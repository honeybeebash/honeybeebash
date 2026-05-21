```text
# ---------------------------------------------------------
# HoneyBeeBash Installer Scripts
# Includes:
# Scikit-Learn Command Classification Research module installation
# ---------------------------------------------------------


## Information:

! IMPORTANT: Avoid permission complications. DO NOT install HoneyBeeBash in a user directory !

If you intend for Bee to execute system-level commands (like apt, systemctl, or restricted file access), you must launch it with the sudo prefix: sudo ./bee.sh.
You can apply the sudo -E flag to preserve environment information if access is failing to certain files.

Always run the Bee installation commands or setup scripts with sudo to ensure that libraries are placed in the system-wide path if no virtual environment is available.

Note that these scripts require network connection for downloading software like the python or google packages.

If you need certain packages stable and not updated during package updates then lock them.
An example of locking Nvidia driver packages is shown in install/lock-versions.sh



## Supported Operating Systems
The installer features automated ecosystem detection and configuration optimization for:

* **Debian / Ubuntu / Linux Mint / Pop!_OS / Kali Linux**
* **Fedora**
* **RHEL / Rocky Linux / AlmaLinux / CentOS** (Will automatically attempt to configure the EPEL repository)
* **Arch Linux / Manjaro**



## Core System Utilities
The host system must have these basic commands available in the shell environment:
* **Bash 4.0+** (The script utilizes advanced Bash-specific arrays and syntax)
* **sudo** (Required to manage root installations and handle privileged directories)
* **getent** (Used to securely map and verify target user home directories)
* **standard coreutils** (`mkdir`, `cp`, `ln`, `sed`, `grep`, `chmod`, `chown`, `basename`, `cut`, `tr`, `id`, `uname`)



## Required Package Dependencies
The script will audit the system and attempt to automatically install the following tools using your native package manager (`apt`, `dnf`, or `pacman`). However, if you are offline or minimal environment restrictions apply, please install them manually:

| Command / Package | Description |
| `python3` | Python 3 runtime environment (Required for execution engine) |
| `python3-pip` | Python package installer |
| `python3-venv` | Python virtual environment library (Crucial for "Backpack Mode") |
| `jq` | Command-line JSON processor (Handles LLM API payloads) |
| `curl` / `wget` | Command-line tools for transferring data and fetching assets |
| `screen` | Terminal multiplexer (Allows monitoring scripts to persist in the background) |
| `openssl` | Cryptographic toolkit for secure communication |
| `bc` | GNU precision calculator language |
| `awk` | Pattern scanning and processing language |
| `zip` / `unzip` | Utilities for packing and unpacking compressed data archives |
| `dos2unix` | Text file format converter (Ensures cross-platform script stability) |

]
## Installation targets:

The global/default configuration will be stored in the user's home directory;
$HOME/.config/honeybeebash directory.

The LLM model files will be stored in the user its home directory as;
$HOME/.local/share/honeybeebash/models directory.

The Bee workspace directories will be created in user home directory as ;
$HOME/.local/share/honeybeebash/workspace

The below scripts will be installed into the /opt/honeybeebash directory;
- bee.sh
- monitor.sh
- detector.py
- tools/*
- backpack/ with python modules


## Installation scripts:

The install/install.sh script has been provided to do as much of the installation work as possible for the average Linux system. It calls upon the install-scikit.sh script for installation of python modules. If in any case an installation was not possible you will be informed to attempt a reinstall or a manual install.

Note that the installer will attempt to install the python packages in a virtual environment (venv) unless in legacy mode.

Download the archive from our website using;
    wget https://honeybeebash.com/downloads/honeybeebash.zip

or from github at https://github.com/honeybeebash/honeybeebash/

Once you have downloaded the installation package change to the src directory of the unpacked HoneyBeeBash download.

> cd honeybeebash/src

Or if downloaded from github;

> cd honeybeebash-main/src

Then run the installer script as root;

> sudo install/install.sh

You will be prompted to answer configuration settings.

When completed you can run Bee.
If installed to a venv (by default) you must enter that container first using;
> source "/opt/honeybeebash/backpack/bin/activate"

Then run Bee with for example;
bee --test



## Manual installation:

If you prefer or are required to manually install the dependencies then find follow the steps below. 
You can also read the installation scripts themselves to find what is required to install.

First install python3 and pip3.

Then install numpy, scikit-learn, pandas and joblib and google-genai.
Note that 'scikit-learn' when installed is listed as 'sklearn'.

```