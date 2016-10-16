# Azure DevTest Labs: gVim Artifact #
## Installs gVim on your VM available to all users ##

For those developers that love the UNIX feel of gVim (or those of us that really don't want to lose our vim skills!) it
is imperative that we have Vim on all of our development boxes. When all else fails, Vim is the default goto for many
developers:

- A build log file too large for Notepad++? Vim.
- No support for an archaic oft-unused programming language? Vim.
- No desktop, minimal shell only? Vim.
- The list goes on.

This artifact will install a current* version of [gVim with Cream-Vim](http://cream.sourceforge.net/) which will bring
all the utility of Vim to your windows VM experience on the Azure DevTest Labs.

## The Script ##

The Install-gVim.ps1 powershell script simply downloads the version of Cream specified on the command line (or defaults
to a relatively recent build) and installs it in unattended mode onto the local machine. You can call it manually as such:

      Install-gVim -VimInstallerPath <localPath> -VimInstallerUri <downloadUri>

Note that the VimInstallerUri can be a 'files' link from SourceForge.net, the redirects that it implies are handled
by the WebClient::DownloadFile C# call. (Powershell calls such as Invoke-WebRequest and Start-BitTransfer have been
found not to work too well).

You can leave the parameters off of the call if you wish, and reasonable defaults will be used. The current defaults
are as follows:

VimInstallerPath = "%TEMP%\gvim.exe"
VimInstallerUri = "https://sourceforge.net/projects/cream/files/Vim/7.4.1641/gvim-7-4-1641.exe/download"

## Known Issues ##

If the VM you are applying this artifact to has a pending reboot, or is currently installing other updates or 
software this artifact will fail. 

Logs supplying the user with information as to the nature of any failures are difficult to discover.

The user ends up with Vim on their system (depending on your POV, this can be an issue).
