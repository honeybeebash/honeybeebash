#!/bin/bash

# prepare.sh
# Set ownership and permissions for the Hive environment
# Run this from the base directory of HoneyBee 

UNAME=$(whoami)
GNAME=$(id -gn) # Gets the primary group name for the user

echo "🐝 Hardening the Hive for user: $UNAME..."

# Set Ownership
sudo chown -R $UNAME:$GNAME .

# Set Directory Permissions 
find . -type d -exec chmod 750 {} +

# Set Base File Permissions 
find . -type f -exec chmod 640 {} +

# Grant Swarm rights
chmod +x bee.sh monitor.sh 

# Handle Subdirectories 
[ -d "tools" ] && chmod +x tools/*.sh
[ -d "install" ] && chmod +x install/*.sh

tools/crlf.sh bee.sh monitor.sh install/*

echo "✅ Permissions locked and loaded."
