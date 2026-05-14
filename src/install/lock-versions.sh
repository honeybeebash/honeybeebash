#!/bin.bash


## Remember not to upgrade as numpy1.x is required
sudo apt-mark hold python3-numpy python3-pandas python3-sklearn


# If Nvidia drivers are used avoid automatic updates 
sudo apt-mark hold $(dpkg -l | grep nvidia | awk '{print $2}')


# Show current locks
apt-mark showhold