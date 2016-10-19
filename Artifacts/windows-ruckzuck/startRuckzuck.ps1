[CmdletBinding()]
param(
    # comma- or semicolon-separated list of RuckZuck packages.
    [string] $PackageList
)

	
cd $($PSScriptRoot)
	
if([string]::IsNullOrEmpty($PackageList))
{
    Start-Process "RZUpdate.exe" -ArgumentList "/Update"
}
else 
    {
        foreach($pkg in $PackageList.Split(",;")) 
        {
		    try
		    {
			    $proc = (Start-Process -FilePath "RZUpdate.exe" -ArgumentList "$($pkg)");$proc.WaitForExit();$ExitCode = $proc.ExitCode
		    } 
            catch{}
	}
}