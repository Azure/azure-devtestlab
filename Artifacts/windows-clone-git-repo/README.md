Clone a git repo
================
This extension does the following – 

 - Installs Chocolatey.
 - Installs Git.
 - Clones specified git repository (hosted on Visual Studio Team Services or Github) to specified destination on the VM.
 - Creates the necessary desktop shortcuts to the local repository and VSTS/github page.  

Parameters
==========

**Git clone URI**

- The url of the Git repository to clone (Only HTTPS urls are supported).
- Examples:
  - https://github.com/myProject.git
  - https://myproject.visualstudio.com/DefaultCollection/_git/SomeProject

**Destination**

 - A parent directory into which your repository will be cloned. 
 - E.g. - If you specify your destination as C:\Repos, then a new sub-directory (C:\Repos\{your local repo}) will be created and your repository will be cloned into it.
 - Note: Cloning into an existing directory is only allowed if the directory is empty. In above example, if C:\Repos\{your local repository} already exists, then the clone operation will fail.

**Branch / Tag**	

 - The branch or tag that will be checked out (use the default 'master' if you're not sure).

**Personal Access Token**

 - Personal Access Token for accessing the Git repository.

Logs
====
This extension generates the log files at the following location on the VM - %SystemDrive%\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\\[version]\Downloads.
