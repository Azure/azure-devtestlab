# Introduction
This script imports a custom role, called AzLabsCustomContributorRole, that you can assign to a teacher at the lab level.  Specifically, the script imports a custom role that gives a teacher the ability to:
- Add\remove students from a lab
- Send an email invitation to a student
- Start\stop\reset a student's VM

Conversely, this custom role denies permissions so that teachers won't be able to perform operations such as:
- Change a lab's quota
- Increase the number of VMs in the pool
- Set a lab's schedule

When a teacher uses the management portal, they will be shown an error message if they attempt to perform an operation that isn't granted by this custom role.

## Notes
- The script must be executed using administrator privileges.
- You must replace "{Your Sub Id}" in the AzLabsCustomContributorRole.json file with your subscription id.

# Directions
1. Replace "{Your Sub Id}" in .\AzLabsCustomContributorRole.json file with your subscription id.
2. Open a PowerShell window.  Make sure that the window notes it is running under administrator privileges.
3. Run `ImportCustomContributorRole.ps1` which imports the custom role defined in .\AzLabsCustomContributorRole.json.

This script will import the custom role into you subscription.  Here are the steps to assign this to a teacher:
1. Assign the teacher the Reader role at the lab account level.
2. Assign the teacher the custom role at the lab level that you want to grant permissions to - the name of the custom role is AzLabsCustomContributorRole.

For related information, refer to the following articles:
- [Azure custom roles](https://docs.microsoft.com/azure/role-based-access-control/custom-roles)
- [Azure Labs Built-in Contributor role](https://docs.microsoft.com/azure/lab-services/administrator-guide#manage-identity)
- [Managing identity](https://docs.microsoft.com/azure/lab-services/administrator-guide#manage-identity)