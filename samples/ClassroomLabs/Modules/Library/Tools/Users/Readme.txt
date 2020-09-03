This scripts will be available
- https://github.com/Azure/azure-devtestlab/tree/master/samples/ClassroomLabs/Modules/Library/Tools/Users

Powershell core
- Install from https://github.com/PowerShell/PowerShell/releases


Structure of ClassesStudents.csv
- ResourceGroupName
    The name of the resource group that the lab account is in.
- LabAccountName
    The lab account name.
- LabName
    The lab name being created.
- AddEmails
    Name of the csv file with the emails of students to add (if the students already exist, then no issues)
- RemoveEmails
    Name of the csv file with the emails of students to remove.
- Invitation
    Title of the invitation email, if you don't want an invitation email sent at lab creation leave this empty.

Structure of Students(1,2,Add,Remove).csv
- Students
    The email of the students to be added or removed.  Single column of email addresses.
