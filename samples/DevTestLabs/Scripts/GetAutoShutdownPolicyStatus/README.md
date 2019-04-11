# Introduction

When you manage multiple labs, it is sometimes important to make sure that all your labs have the Auto-Shutdown policy enabled.  This can be a tedious exercise if you have many labs to examine.  To automate this process, we have introduced a PowerShell script that will look at all your labs and verify they are opted-in to the Auto-Shutdown lab policy. 

The syntax of the script is as follows:
```powershell
GetAutoShutdownPolicyStatus.ps1 [-SubscriptionIds] [-LabName] [-Verbose]
```

Examples:
```powershell
# Verify the Auto-shutdown status on all labs in all your subscriptions
GetAutoShutdownPolicyStatus.ps1 

# Verify the Auto-shutdown status on a single subscription and output verbose logging
GetAutoShutdownPolicyStatus.ps1 -SubscriptionIds "<my subscription id>" -Verbose

# Verify the Auto-shutdown status on a single lab
GetAutoShutdownPolicyStatus.ps1 -SubscriptionIds "<my subscription id>" -LabName "MyLab"
```