[CmdletBinding()]
param(
    #semicolon-separated list of RuckZuck packages.
    [string] $PackageList
)
	
cd $($PSScriptRoot)

#RZUpdate.exe V1.1.0.4 from https://ruckzuck.codeplex.com/
#Check if Package-List is empty..	
if([string]::IsNullOrEmpty($PackageList))
{
	#Update all existing Software
    $proc = (Start-Process -FilePath "RZUpdate.exe" -ArgumentList "/Update")
	$proc.WaitForExit()
	$ExitCode = $proc.ExitCode
    Exit($ExitCode)
}
else 
{
	#Install all Products from the Package-List
	try
	{
	    $proc = (Start-Process -FilePath "RZUpdate.exe" -ArgumentList "$($PackageList)")
		$proc.WaitForExit()
		$ExitCode = $proc.ExitCode
	} 
    catch{}
}