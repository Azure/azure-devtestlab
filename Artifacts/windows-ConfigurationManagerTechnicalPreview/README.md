#System Center Configuration Manager Technical-Preview
This Artifact will install System Center Configuration Manager Technical-Preview.
More Details on: https://docs.microsoft.com/en-us/sccm/core/get-started/technical-preview 

### Requirements:
Tested with the base Image: "SQL Server 2016 SP1 Standard on Windows Server 2016". If you choose another Image, make sure that the following componets are installed:
- Windows Server 2012 R2 (or newer)
- .NET 3.5
- .NET 4.5
- MS SQL 2014 SP1 (or newer)
- **Server must be Domain Joined !!!**. You can use the Artifact "**Create new Domain**" to create a new AD Domain.

### Input Parameters:
The Artifact contains two Parameters:
- SCCM Site Code (3-Digit)
- SCCM Site Name

If you leave these Parameters blank, it will use the Site-Code "TST" and Site Name "Test Site".


###Installation Steps
If Server is not Domain-Joined:
- Add the Artifact "Create new Domain" before installing the ConfigMgr Artifact.

Sub-Tasks of the Artifact:
```
- Create c:\sccmsetup.ini (unattend File for SCCM Setup) if the File does not exist
- Tweak SQL to grant LocalSystem SysAdmin rights
- Change SQL to run as LocalSystem
- Install ADK10
- Install CMTP
- Grant "Domain Admins" full Admin rights in SCCM
- Install ConfigMgr Toolkit
- Install Collection Commander
- Install Client Center
- Install RuckZuck4ConfigMgr
- Install SCUP
```

###Duration:
End-to-End setup on a single core Machine with 4GB Memory took a bit more than one hour...

###Troubleshooting
- If CM is missing
 - check if Server is member of a Domain
 - check if ADK is installed
 - check c:\windows\temp if there is a .CAB File in a subfolder with ~600MB
 - check c:\windows\temp\smsetup, to size of all files should be ~1GB
 - check c:\ConfigMgrSetup.log

