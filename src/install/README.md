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



## Requirements:

Python3 is required to run the detector.py script.
pip3 is required to install python modules like Sci-Kit and Google-genai

The below listed common tools are required and will be installed automatically if needed;
bc, awk, curl, wget, jq, zip, unzip, dos2unix, screen, openssl

The following required Python modules will be installed automatically if needed;
sciKit-learn, pandas, joblib

For local LLM usage the following are suggested;
docker, ollama, qwen2.5-coder

We are working on a combined install script for this but some are already available online.



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

Once you have downloaded the installation package change to the src directory of the unpacked HoneyBeeBash download.

> cd honeybeebash/src

Then run the installer script as root;

> sudo install/install.sh

You will be prompted to answer configuration settings.

When completed you can run Bee.
If installed to a venv (by default) you must enter that container first using;
> source "/opt/honeybeebash/backpack/bin/activate"

Then run Bee with for example;
bee "



## Manual installation:

If you prefer or are required to manually install the dependencies then find follow the steps below. 
You can also read the installation scripts themselves to find what is required to install.

First install python3 and pip3.

Then install numpy, scikit-learn, pandas and joblib and google-genai.
Note that 'scikit-learn' when installed is listed as 'sklearn'.

```