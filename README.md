```text
# ---------------------------------------------------------
# HoneyBeeBash (The Buzzy Bash Agent)
# Controlled by AI: LAN or GeminiFlash or GoogleApi
# Quad-Tiered Risk Mitigation LLM+Black+White+Trained
# Inspired by: GitHub Open Source Security Community
# Training by:
# Scikit-Learn Command Classification Research
# Core ML Logic: RandomForest + TF-IDF Vectorization
# ---------------------------------------------------------


## Project Info
**Version:** 1.0.0  
**Author:** M.D.P de Clerck ([mike@clerck.nl](mailto:mike@clerck.nl))  
**License:** [GNU General Public License v3](LICENSE)


## Summary:

HoneyBeeBash is a LLM geared lightweight bash server tool built for direct, broad scale server and process maintenance. 

Bee was developed to assist the user with server maintenance. Providing deep discovery and a executable solutions while maintaining control over its impact.

By operating directly in Bash it eliminates traditional middleware, securing the execution layer through a Quad-Tiered Command Validation architecture.

Built to be fast, transparent, and community-driven.

[!IMPORTANT]
Bee.sh is not a "fire and forget" tool. 
It is designed for initial supervised deployment. Users must calibrate rulesets to match their specific environment and/or job. 



## Introduction:

HoneyBeeBash (Bee for short) is designed to safely grant an AI model structured, administrative Linux system access through a native Bash shell.

This power is harnessed to perform recovery, maintenance and review tasks in depth.

Unlike standard LLM-based agents that may hallucinate destructive commands, Bee.sh utilizes a hybrid cognitive model:

The Pre-frontal Cortex (AI)
Handles complex reasoning and task planning.

The Survival Instinct (Signatures & SciKit Heuristics)
A "primitive" safety layer that intercepts intercepts destructive path execution attempts (malformed or dangerous commands) before they reach the kernel. Even if the AI fails, the signature-based safety net prevents system-level catastrophes.

The Human Factor
If the LLM cannot decide if the command is low risk it will request human response to proceed. 


## System Architecture:
The framework operates on a feedback loop where AI-driven logic is constrained by rigid, heuristic safety boundaries as shown below:

      HIVE <--> QUEENBEE <--> MONITOR
                    ^           ^     
                    v           |              
                   BEE <--> JOB WORKSPACE
                    |           v     ^                   
   GLOBAL RULES --> X <-- JOB RULES   |
                    v                 |
      OS <--> BASH CONTROL --> COMMAND OUTPUT

Note that the QueenBee hive tool requires an upgrade. 




## Requirements:

Python3 is required to run the detector.py script.
pip3 is required to install python modules like Sci-Kit and Google-genai

The below listed common tools are required and will be installed automatically if needed;
bc, awk, curl, wget, jq, zip, unzip, dos2unix, screen, openssl

The following required Python modules will be installed automatically if needed;
sciKit-learn, pandas, joblib

For local LLM usage the following are suggested;
docker, ollama, qwen2.5-coder

I am working on a combined install script for this but some are already available online.

For information on the installation process see the README.md in the install folder.



## Run examples:

> bee                                       - Continue existing job or start (first) default job 
> bee "Skip mail logs."                     - Continue with tip
> bee new "job_name"                        - Start new job with default prompt
> bee new "Custom prompt" "job_name"        - Start new job with custom prompt
> bee "How much RAM do i have ?"            - End with a ? character to ask a system related question
> bee --ask "Where to penguins live ?"      - Ask a general question report answer and exit
> bee --import=zombie-hunt                  - Import and run the default version of the zombie-hunt job 
> bee --forget "cmd"                        - Run the unlearn script for a specific command
> bee --merge                               - Merge job rules with global rules

You can find example output and logs on the website https://honeybeebash.com/examples



## Usage:

Find below available parameters of Bee. 
Note that after installation 'bee' should be a working symbolic link to bee.sh.
 

Usage: bee "[PROMPT]" [JOB_NAME]:[VERSION] [OPTIONS]
Default action: Continues last job.

CORE COMMAND OPTIONS:
  --help                  Show this help information
  --version               Show the version number of Bee
  --timeout=n             Override default LLM timeout (seconds). For testing and tuning.
  --delay=n               Set the amount of seconds to wait between LLM requests.
  --verbose=0-2           Show less output (0) or more (2) [CONFLICT] [WARNING] [NOTICE]
  --silent                Show no output  
  --debug=0-3             Set debug level (0 none - 3 full)  
  --update                Obtains the latest version and installs the scripts only for immediate use
  --exit                  Exit after processing parameter commands

HIVEHUB OPERATION OPTIONS:
  --review=JOB            Echo out all files of the global and job ruleset for review.
  --importall=JOB         Import all as job and global default dataset. Usually just run once.
  --import=JOB            Import the bee profile and job ruleset. Regular for new jobs types.
  --importrules=JOB       Import the job ruleset (job specific) only and keep your profile.
  --importglobal=JOB      Import the global bee profile and run rules (distro specific).
  --importglobalrules=JOB Import the global run rules (distro specific) only and keep profile.
  --exportall=JOB         Export all including the bee profile, global and job ruleset.
  --export=JOB            Export only the bee profile and ruleset from that job.
  --exporttext="TEXT"     Provide a text description for your export package.
  --exportusername=email  Set and store your obtained HiveHub username
  --exportapikey=key      Set and store your obtained HiveHub API key
  --merge                 Add the job ruleset to local global default ruleset (appending).
  --mergehive             Promote job ruleset to Hive global set [Requires Hive tool]

DATA & RULE OPTIONS:
  --rebuild               Re-train the SciKit-Learn datamodel
  --forget=\"CMD\"         Remove a command from the job rulesets

LLM MODEL OPTIONS:
  --model=MODEL           Change active LLM resource (local, geminiflash, googleapi)
  --googleapikey=key      Set and store your obtained Google API key

JOB MANAGEMENT OPTIONS:
  --ask [QUESTION]        Ask a single general question to the LLM
  --new [JOB]             Start new job & clear logs (or use 'new' as 1st arg)
  --jobs                  Lists all local available jobs
  --drop=JOB              Permanently delete a specific job directory
  --clone=JOB             Copy a specific local dataset to a the one specified in --target 
  --target=JOB            The target JOB:VERSION of the cloned dataset
  --clearrules            Clear Run rules (Always/Never/Replace) for current job
  --clean                 Clear current job logs



## Execute Approval:

Bee will ask you if it can execute certain commands. You can press a key to answer to such request. 

In the shell you can answer to these request using the following keys;

(Y)es , runs the command
(O)nce , runs the command without training
(S)kip , skips the command
(A)lways , adds the command to the RUN_ALWAYS list
(N)ever , adds the command to the RUN_NEVER list
(R)eplace , asks for a replacement command and stores and executes it.
(F)ollowup , skips command and allows you to enter a followup message for the LLM. 
(Q)uit , exits Bee.



## Workspace:

Each running Bee can handle one job/session.
For each job a 'job directory' is created in the user's $HOME/.local/share/workspace.

Upon starting a new job the default BEE_PROFILE, BEE_RULES and BEE_PLANNING are copied to the new workspace directory.
The global RUN_* files are not copied as they are active on each run together with the job RUN_* files.
The files in the job directory can be altered to fit the new job with specific details and rules.

The workspace stores the config, cache and data files allowing Bee and users to monitor the exact functioning. 
See the examples directory for such examples.

On a running job the job directory contains;

GOAL            The initial prompt as goal for this job
PLAN            The generated step based plan
FACTS           Gathered usefull facts
FOCUS           A summary with goal, planning, input, next command and explanation.
HISTORY         A compacted history of given command and received result
JOURNAL         A full journal of all information this session (auto rotates)
LOG             A full log of given prompts and received response
PROMPTLOG       A log of just the given prompts
LASTPROMPT      The last full formatted prompt used
COMMANDLOG      A log of executed commands during this session
BEELOG          Events and actions of Bee
RESULT          The raw AI response
RESULT2         A truncated or filtered result

config/
BEE_PROFILE     A profile describing how Bee's used AI model should act
BEE_RULES       Rules describing limits and format for the AI model to answer a question
BEE_PLANNING    Rules describing limits and format for the AI model to make a planning
DEFAULT_INPUT   This is the default input to start Bee with.
RUN_FORBIDDEN   Strings that trigger an automatic rejection
RUN_ALWAYS      Bash command lines that are always allowed
RUN_NEVER       Bash command lines that are always rejected
RUN_REPLACE     Bash command lines that are replaced

cache/
dataset.csv
model.pkl       The trained algorithm model (the weights)
vectorizer.pkl  The trained numerical model (the dictionary)

memory/         Any data files that Bee decides to use as long term memory for this job
archive/        Any data to be archived Bee will store here.
tmp/            Any files that Bee found temporarly useful to store data for this job

! Workspace files other than the profile, rules and dataset.csv are deleted when starting a new session.



## Memory:

Bee has a memory directory to use as temporary memory if needed and is instructed to use it.
Memory is wiped when starting a new session.
Note: Training the Bee generates cache/vectorizer.pkl and cache/model.pkl in the job directory. These files represent the Bee's 'gut instinct.' If you delete them, the Bee will lose its ability to detect malicious commands until it is re-trained.

Privacy risks and chills:
Bee comes with a local and remote mode allowing for use of local LAN basee ollama models to aid in the job.
This guarantees no data of your system makes it to the outside world at ZERO token costs other then the power bill.
Bee also comes with a ready-to-go remote mode that connects to Gemini Flash to make use of its enourmous context window. 



## Bash tools:

Bee comes with a few scripted tools to make its work easier and keep code overhead low.

tools/forget.sh - Used by Bee to forget a command from its ruleset
tools/merge.sh - Used by Bee to collect training data and merge with the default config for new jobs.



## Monitor tool:

Bee comes with a monitor/dashboard allowing you to easily follow its progress, view its logs, change jobs, run Bee's and more.
All the information in the monitor is available in files but the monitor shows them in realtime on one screen and allows easy switching.

The monitor should provide all information to run and verify Bee's work. 
In the Monitor you can also answer the execution approval request with the exception of Replace and Followup. 

If desired you can alter the monitor.sh to alter its keybinding or provide more information or re-arrange layout of each page.

Run the monitor in another shell or if Bee is running in the background;

> monitor

Use the '?' key to view options.
Note that the monitor has activity tracking by PID and uses 'kill 0' to check status of the user's bees. Run the monitor with sudo -E to follow any job of any user.

The monitor can also launch Bee's, to do so press B and enter its parameters "prompt" and "jobname" or leave all empty for the default job.
This launches bee.sh in a new virtual session that you can re-connect to from a terminal using the command;

> screen -r {jobname}



## Bee Profile and Configuration:

The Bee Bash script requires config/bee.conf to manage LLM selection, timeouts, and security modes. This file is generated during installation; manual alteration is rarely required.

Bee utilizes profiles and rulesets to instruct the LLM. While these files are fully customizable, ensure they do not exceed the configured LLM context size.

BEE_PROFILE   - Describes the non-technical response behavior of Bee
BEE_PLANNING  - Describes the instructions for the first planning step
BEE_RULES     - Describes the instructions and rules for the actual job work 
DEFAULT_INPUT - This is the default input for the LLM for this job 

Bee always applies the profile and instructions from its job directory to instruct the LLM.
For protection it applies the global RUN-rules (distro specific) as well as the job RUN-rules (job specific).
This separation allows users to safely vary the rules per job while maintaining a global protection layer.

RUN-rules declare commandlines that are trusted, undesired or replaceable with a local fitting alternative. These rules are processed before any command is executed. The following RUN-rules are applied;

RUN_FORBIDDEN: Immediate rejection if a blacklisted string is detected.
RUN_ALWAYS: Immediate execution for verified, high-trust command patterns.
RUN_NEVER: Strict block for specific, absolute-match commandlines.
RUN_REPLACE: Transparently swaps a requested command for a local alternative.
PREDICT (dataset.csv): Rejects commands scoring high-risk via SciKit-trained weight analysis.

The global rulesets are stored in the main config directory. 
For new jobs the global profile and RUN-rules are copied from config/ to the new job directory.
For new jobs the default prediction ruleset (config/default-dataset.csv) is also copied to the new job directory.

The global rulesets are used to protect you from known risks on the system it runs on. For example you may want to deny global package updates or working in specific files or directories. The job rulesets are used to instruct specifics for a certain job. For example detailed instructions on the functioning of the mail stack on that system for review.



## Risk Mitigation measures:

The tiered defence brings black and whitelist guarantees as well as dynamic training and learning capabilities.
The Signature Tier relies on exact matches in RUN_ALWAYS, RUN_NEVER and RUN_REPLACE as well as string based matches in RUN_FORBIDDEN.
The Heuristic Tier does Pattern recognition and probability on .pkl models.

To enable autonomous jobs Bee has 3 automation modes which are;

- RESTRICTIVE = Automate on perfect safety score only
- PERMISSIVE = Automate on =<10% threat score
- MANUAL = No automation, approve all commands

The tiered defence processes in the following order;

Normalization: Check RUN_REPLACE. If it matches, swap the command.
Signature Check (Known): Does it contain a known undesired string. If yes, WARN.
Signature Check (White): Is it in RUN_ALWAYS? If yes, EXECUTE.
Signature Check (Black): Is it in RUN_NEVER? If yes, WARN.
Heuristic Check (Local): Run detector.py.
    Score 10? EXECUTE.
    Score 9? EXECUTE (if permissive).
Manual Intervention: If it survives the first 4 steps but isn't "Trusted," it hits the User Prompt to ask for approval response.



The heuristic learning detection layer [SciKit Panda]:

Scikit-learn is a massive library for Machine Learning. This library is applied in the detector.py script that uses a training dataset to learn command rules to detect undesired commands. 

The code follows a standard "Train then Predict" workflow:

1. The Vectorizer (TfidfVectorizer) turns text commands into numbers. It looks for "keywords" that appear in malicious commands but rarely in normal ones (like rm, rf, base64, or dev/tcp).

2. The Brain (RandomForestClassifier) is an ensemble of "Decision Trees." Imagine a hundred little "Yes/No" flowcharts. One tree might ask, "Does it have sudo?", another asks, "Is there a weird IP address?". They all vote, and the majority wins.

When the Bee attempts to use a command suggested by the LLM, the model calculates the probability that it matches the "malicious" patterns it learned from dataset.csv. If it fails this last layer of detection then Bee will ask for manual response for that command. This process extends the dataset.csv with approved commands during use.



## Import/Export via HiveHub:

HoneyBeeBash supports sharing of datasets (configuration files) to improve the quality and security for the entire community. These files are managed via HiveHub, the central HoneyBee Hive repository.

HiveHub categorizes configurations by distribution. Users can submit (--export), download (manual or with --import), upvote and downvote rulesets. 

The listing can be browsed per distro or searched for rulesets for a specific job. 



## Privacy and Security:

Rulesets may contain identifiable arguments from manual approvals. While HiveHub filters and reviews submissions for profanity and PII (Personally Identifiable Information), users should review rulesets before exporting to ensure data is anonymized. 

You can use the following flag to echo the full ruleset to one file for review;
> bee.sh --review=default > RULESET_REVIEW.txt

Always inspect imported rulesets to verify the instructions being sent to your system. 
All files are stored in plain ascii and can be reviewed using any editor or the monitor.



## Import Flags:

Bee will import the default job for your distro on startup.
Find below examples to add more jobs for bee by importing them from HiveHub.

To import all as fresh global default dataset you use the below parameter. This is usually just run once or to reset.
> bee.sh --importall=default

Once your global ruleset covers the high-risk commands to your satisfaction, you can safely test various job rulesets using the below parameter.
This will import the bee profile and job ruleset to your job directory. This is the regular approach for starting new jobs.
> bee.sh --import=default

To import the job ruleset only and keep your bee profile files the below command only imports the job rules to your job directory.
> bee.sh --importrules=default

To import the distro specific global run rules the below command only imports the global run rules and default dataset to your main config directory. 
> bee.sh --importglobal=default



## Export Flags:

To share your custom altered jobs with the rest of our Bee community you can export them using the below flags;

To export only the bee profile and ruleset from that job.
> bee.sh --export=default

To export all including the bee profile, global and job ruleset.
> bee.sh --exportall=JOB

To process your export and authorize at our API the following flag is required when exporting;

> bee.sh --exporttext="TEXT"     Provide a text description for your export package.

If you have installed before obtaining a HiveHub account then you can set and store your username (email) and API key with these flags;

Set and store your obtained HiveHub username.
> bee.sh --exportusername=email  

Set and store your obtained HiveHub API key.
> bee.sh --exportapikey=key      



## Bee Runtime tips:

The default prompt size is around 2000 tokens. 

Bee will often loop over the same command to see variations in time.

Avoid answering Always to commands with usernames, use Yes to teach.

Run --verbose=2 for maximum output. Suggest you turn your screen 90 degrees as it is a lot of output.

For now Bee has no mail support but Bee can be instructed to write to files in its workspace sub folders. 
Such files could be used to detect and mail the results to the user.

For long running jobs like monitor jobs i suggest setting the --delay value longer than the default 5 seconds.

If issues occur or you are curious about more internal functioning then you can add the flag --debug=3 for maximum debug output.
                
Bee runs sudo itself but this will require you to authenticate with a password regularly then.
You can add a honeybee user to the sudoers list or call bee with sudo -E.
Using the -E flag preserves the environment so all files and packages can be found.

> sudo -E bee
```


  
