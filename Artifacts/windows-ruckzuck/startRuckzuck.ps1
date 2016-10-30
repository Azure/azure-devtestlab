[CmdletBinding()]
param(
    # comma- or semicolon-separated list of RuckZuck packages.
    [string] $PackageList
)

	
cd $($PSScriptRoot)
	
if([string]::IsNullOrEmpty($PackageList))
{
    $proc = (Start-Process -FilePath "RZUpdate.exe" -ArgumentList "/Update");$proc.WaitForExit();$ExitCode = $proc.ExitCode
    Exit($ExitCode)
}
else 
{
	try
	{
	    $proc = (Start-Process -FilePath "RZUpdate.exe" -ArgumentList "$($PackageList)");$proc.WaitForExit();$ExitCode = $proc.ExitCode
	} 
    catch{}
}