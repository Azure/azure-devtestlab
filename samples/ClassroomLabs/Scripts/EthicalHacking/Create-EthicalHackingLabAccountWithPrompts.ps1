[CmdletBinding()]
param()

###################################################################################################
#
# Handle all errors in this script.
#

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe script failed to run.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Main execution block.
#

#Import Az Module if not done already
Import-Module Az
Login-AzAccount 

#Prompt user for necessary information
$email = Read-Host "Your email"
$adminUsername = Read-Host "Machine username"
$adminPassword = Read-Host "Machine password"
$possibleLocations = Get-AzLocation | Where-Object Providers -contains 'Microsoft.LabServices' | Select-Object -expand Location   
Write-Host "Possible location values are $($possibleLocations -join ',')"         
$location = Read-Host "Choose location from values listed above"

#Run script that will actually create the lab account and lab for the ethical hacking class
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Scripts/EthicalHacking/Create-EthicalHacking-LabsAccount.ps1" -OutFile Create-EthicalHacking-LabsAccount.ps1
./Create-EthicalHacking-LabsAccount.ps1 -Email $email -UserName $adminUsername -Password $adminPassword -Location $location

Write-Host "Done!" -ForegroundColor 'Green'