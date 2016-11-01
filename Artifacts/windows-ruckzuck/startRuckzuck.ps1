[CmdletBinding()]
param(
    #semicolon-separated list of RuckZuck packages.
    [string] $PackageList
)
	
cd $($PSScriptRoot)

if((Test-Path "$($env:temp)\RZUpdate.exe") -eq $false) 
{ 
	(New-Object System.Net.WebClient).DownloadFile("https://ruckzuck.azurewebsites.net/DL/RZUpdate.exe", "$($env:temp)\RZUpdate.exe") 
}

#RZUpdate.exe from https://ruckzuck.codeplex.com/
#Check if Package-List is empty..	
if([string]::IsNullOrEmpty($PackageList))
{
	#Update all existing Software
    $proc = (Start-Process -FilePath "$($env:temp)\RZUpdate.exe" -ArgumentList "/Update")
	$proc.WaitForExit()
	$ExitCode = $proc.ExitCode
    Exit($ExitCode)
}
else 
{
	#Install all Products from the Package-List
	try
	{
	    $proc = (Start-Process -FilePath "$($env:temp)\RZUpdate.exe" -ArgumentList "$($PackageList)")
		$proc.WaitForExit()
		$ExitCode = $proc.ExitCode
	} 
    catch{}
}