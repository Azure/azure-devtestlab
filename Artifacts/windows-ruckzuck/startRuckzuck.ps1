[CmdletBinding()]
param(
    #semicolon-separated list of RuckZuck packages.
    [string] $PackageList
)
	
Set-Location $($PSScriptRoot)

if((Test-Path "$($env:temp)\RZUpdate.exe") -eq $false) 
{ 
	(New-Object System.Net.WebClient).DownloadFile("https://ruckzuck.azurewebsites.net/DL/RZUpdate.exe", "$($env:temp)\RZUpdate.exe") 
}

#Check if Package-List is empty..	
if([string]::IsNullOrEmpty($PackageList))
{
	#Update all existing Software
    $proc = Start-Process -FilePath "$($env:temp)\RZUpdate.exe" -ArgumentList "/Update" -PassThru
	$proc.WaitForExit()
	$ExitCode = $proc.ExitCode
    Exit($ExitCode)
}
else 
{
	#Install all Products from the Package-List
	try
	{
	    $proc = Start-Process -FilePath "$($env:temp)\RZUpdate.exe" -ArgumentList "$($PackageList)" -PassThru
		$proc.WaitForExit()
		$ExitCode = $proc.ExitCode
		Exit($ExitCode)
	} 
    catch{}
}