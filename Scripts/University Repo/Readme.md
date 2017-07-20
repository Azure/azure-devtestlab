
University repository

This repository has been created to collect the required material to set up DevTest Labs in Univerisities. This is useful both for IT admin and students because the former won't have to maintain physical machines, the latter will always have fresh machines available both for classes and self-service usage.

It contains:

Scenario Scripts folder contains scripts which need to be run either via Console or via Automation account
on Azure to set up the environments for the imagined scenarios.

Roles folder contains the json file which specifies the actions that a University user can take on a VM

Shutdown scripts folder contains the scripts to automatically shutdown a VM if it's not used for a certain period of time

LoadIdleScript: This script creates a task inside Windows Task Scheduler getting a file script from a blob storage.

ShutdownOnIdleV2: This script shutdowns the machine if the user hasn't been active.

Simplifies JS portal contains the files needed to set a simplified portal for the students to claim a VM in an easier way
