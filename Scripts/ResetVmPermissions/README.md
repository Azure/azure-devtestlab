# Re-establish role assignments

If you need to re-establish the Owner permissions on a lab virtual machine and you do not want to use the Azure Portal, you can use the script included in this folder.  Without additional parameters, this script will enumerate the subscriptions and labs you have access to and re-establish the permissions for each lab virtual machine in each lab.  You can provide an explicit list of subscriptions if you only want to update certain subscriptions instead of all accessible ones. Also, if, in addition to re-establishing the Owner role assignment on each lab virtual machine, you also want each lab virtual machine owner to be a "DevTest Lab User" or an "Owner" on the corresponding Lab, you can do so via the `LabRoleToAdd` parameter.

Examples:

```
# Re-establish all lab virtual machine owner permissions on all labs in all your subscriptions
./FixRoleAssignments.ps1

# Re-esablish lab virtual machine users for subscriptions sub1, sub2, and sub3, and ensure that each lab virtual machine owner is a DevTest Lab user
./FixRoleAssignments.ps1 -SubscriptionIds ('sub1','sub2','sub3') -LabRoleToAdd "DevTest Labs User"

# Re-esablish lab virtual machine users for subscriptions sub1, sub2, and sub3, and ensure that each lab virtual machine owner is a DevTest Lab owner
./FixRoleAssignments.ps1 -SubscriptionIds ('sub1','sub2','sub3') -LabRoleToAdd "Owner"
```