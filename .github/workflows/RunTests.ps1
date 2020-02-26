param ([SecureString]$password, $tests)


Install-Module Pester -Force
Install-Module Az -Force
$User = "2075d471-a457-4e68-8723-6f3859c2360c"
$PWord = ConvertTo-SecureString -String $password -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Connect-AzAccount -Credential $Credential -Tenant "72f988bf-86f1-41af-91ab-2d7cd011db47" -ServicePrincipal
Invoke-Pester (Join-Path "./samples/ClassroomLabs/Modules/Library/Tests/" $tests) -EnableExit