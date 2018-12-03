Param
(
	[Parameter(Mandatory=$true)]
    [string] $JDKVersion
)

# Need an upfront check for powershell 3 - this is required for chocolatey
if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Error "Please install at least PowerShell 3 to use this artifact.  Your version is: $($PSVersionTable.PSVersion.ToString())"
}
else {
    Write-Output "Version of JDK to install: $JDKVersion"

    if ($JDKVersion -eq "jdk10") {
        # Instal wix with chocolatey installer
        Write-Output "Installing via chocolatey package 'jdk10'"
        InstallChocoPackages jdk10
    }
    elseif ($JDKVersion -eq "jdk8") {
        # Instal wix with chocolatey installer
        Write-Output "Installing via chocolatey package 'jdk8'"
        InstallChocoPackages jdk8
    }
    else {
        Write-Error "Invalid option, unable to install $JDKVersion"
    }
}
