#System Center Configuration Manager CurrentBranch (EVAL)
This Artifact will install System Center Configuration Manager CurrentBranch (Build 1606) Evaluation Edition (usable for 180 Days).

### Requirements:
Tested with the base Image: "SQL Server 2014 SP1 Standard on Windows Server 2012 R2". If you choose another Image, make sure that the following componnets are installed:
- Windows Server 2012 R2 (or newer)
- .NET 3.5
- .NET 4.5
- MS SQL 2014 SP1 (or newer)

### Domain Join:
If ther Server is not Domain-Joined, the Artifact will create a "contoso.com" Domain on the target Server and reboot.
For Workgroup Servers: **you have to assign this Artifact twice !** The first time to create and join the Domain and the second time to install ConfigMgr.

### Input Parameters:
The Artifact contains two Parameters:
- SCCM Site Code (3-Digit)
- SCCM Site Name

If you leave these Parameters blank, it will use the Site-Code "TST" and Site Name "Test Site".


###Installation Steps
```
If not Domain-Joined:
- Create a new Domain Controller for "contoso.com" -> Reboot
```
```
If Domain-Joined:
- Create c:\sccmsetup.ini (unattend File for SCCM Setup) if the File does not exist
- Tweak SQL to grant LocalSystem SysAdmin rights
- Change SQL to run as LocalSystem
- Install ADK10
- Install CMCB
- Install SCCM PowerShell CMDLets
- Grant "Domain Admins" full Admin rights in SCCM
- Install ConfigMgr Toolkit
- Install Collection Commander
- Install Client Center
- Install RuckZuck4ConfigMgr
- Install SCUP
```

###Duration:
End-to-End setup on a single core Machine with 4GB Memory took a bit more than one hour...
