# Updating Tags for a DevTest Lab
Azure DevTest Labs supports propogation of tags from the lab to the resources created by the lab (Virtual Machines and Environments).  There are cases, however, where there is a need to change/update the tags on a lab.  DevTest Labs doesn't go update any *existing* resources, the tags are only applied to new resources.

The script below, "Update-DevTestLabsTags.ps1" provides a way to update existing resources for a lab and propogates either new tags (or tag value changes) to the Lab-related resources.

The syntax of the script is as follows:
```powershell

# This script grabs the Lab's tags and updates the tags on the lab's related resources
.\Update-DevTestLabsTags.ps1 -ResourceGroupName "MyLab-rg" `
                             -DevTestLabName "MyLab"

```
