This scripts will be available
- https://github.com/Azure/azure-devtestlab/tree/master/samples/ClassroomLabs/Modules/Library/Tools

Powershell core
- Install from https://github.com/PowerShell/PowerShell/releases


Structure of Hogwarts.csv
- ResourceGroupName
    The name of the resource group that the lab account is in.
- Location
    The region southcentralus.
- LabAccountName
    The lab account name.
- LabName
    The lab name being created.
- ImageName
    The image name that the lab will be based on.
- MaxUsers
    Maximum number of users.
- UsageQuota
    Maximum quota per student.
- UsageMode
    Type of usage either "Restricted" - only those who are registered, or "Open" anyone.
- SharedPassword
    A single shared password - True or False.
- Size
    The VM size listed below
        Basic, MediumGPUVisualization, Performance, SmallGPUCompute, SmallGPUVisualization, Standard, Virtualization, Large    
- Title
    Title for the lab
- Descr
    Description for the lab.
- UserName
    Default user name.
- Password
    Default password.
- LinuxRdp
    Does the VM require a Linux RDP - True or False.
- Emails
    Semi colon seperated string of students ie "bob@test.com;charlie@test.com" to be added to the lab.
- Invitation
    Title of the invitation email, if you don't want an invitation email sent at lab creation leave this empty.
- Schedules
    Name of the csv file that contains the schedule for this class.  Ie "Schedule"

Structure of charms.csv
- Frequency
    How often, "Weekly" or "Once"
- FromDate
    Start Date
- ToDate
    End Date
- StartTime
    Start Time
- EndTime
    End Time
- WeekDays
    Days of the week.  "Monday, Tuesday, Friday".  The days are comma seperated with the text. If Frequency is "Once" use an empty string "" 
- TimeZoneId
    Time zone for the classes.  "Central Standard Time"
- Notes
    Additional notes.
