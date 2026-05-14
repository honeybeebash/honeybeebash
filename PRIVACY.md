Privacy policy: HoneyBeeBash & Hive Ecosystem
                

1. Data Collection & Storage

HoneyBeeBash operates locally on your system. By design, it collects and stores the following information:

- System Logs: The Software generates local log files to monitor performance and troubleshoot execution errors within your Bash environment.
- Local Datasets: Data processed by the Software is stored locally on your machine or server.

Note: Unless you explicitly choose to export your data, all information remains strictly on your local infrastructure.



2. Data Export to HiveHub

HoneyBeeBash provides a feature allowing users to export datasets to HiveHub. 
Exporting only includes profile and rules data (the dataset). No logs are ever sent. 
When you initiate an export:

- Transmission: The dataset is transmitted from your local environment to HiveHub's servers.
- Anonymization: Upon receipt, HiveHub performs a "scrubbing" process. This removes:

&nbsp;&nbsp;&nbsp;&nbsp;Personal Identifiable Information (PII): Names, email addresses, etc.
&nbsp;&nbsp;&nbsp;&nbsp;Server Identifiable Content: IP addresses, hostnames, and specific server metadata.

- Publication: Only the scrubbed, anonymized version of the a is published on the HiveHub platform.



3. Data Residency & GDPR Compliance

For users registering on HiveHub and by doing so providing account credentials to facilitate HiveHub integration, the following applies:

- Data Types: We store your username, email address, and API key.
- Storage Location: All account-related data is hosted on secure servers located within the European Union (EU).
- Legal Basis: This data is processed based on Contractual Necessity (to provide the connection service to HiveHub) and complies with GDPR requirements regarding data sovereignty and protection.
- Security: API keys are encrypted at rest, and all communications between the HoneyBee Bash script and our European servers are conducted via encrypted protocols (HTTPS/TLS).



4. Data Security

Because HoneyBeeBash runs in a Bash environment, the security of the local logs and datasets depends on your own system's security configurations.
We recommend:

- Restricting file permissions on HoneyBeeBash log directories.
- Using secure protocols (e.g., HTTPS/SSH) when communicating with HiveHub.



5. User Control

You have total control over your data:

- Deletions: You may delete local logs and datasets at any time using standard terminal commands.
- Opt-in Export: No data is sent to HiveHub automatically; transmission only occurs via user-initiated commands.
- Manual scrubbing: Before exporting you can manually scrub the rulesets to assure nothing personal arives at HiveHub.



6. Changes to This Policy

We may update this policy to reflect changes in the Software's functionality. Users are encouraged to check the documentation periodically for updates.
