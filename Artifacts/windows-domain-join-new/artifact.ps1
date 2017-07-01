[CmdletBinding()]       
param
(
    [Parameter(Mandatory=$true)]
    [string] $domainJoinUsername,

    [Parameter(Mandatory=$true)]
    [string] $domainAdminUsername,

    [Parameter(Mandatory=$true)]
    [string] $domainAdminPassword,

    [Parameter(Mandatory=$true)]
    [string] $domainToJoin,

    [Parameter(Mandatory=$true)]
    [string] $ouPath
    
)

if ($PSVersionTable.PSVersion.Major -lt 3) {
	Write-Error "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell 3 or higher installed."
}
else {
    $securePass = ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($domainAdminUsername, $securePass)

    Write-Output "Attempting to join the domain..."
    [Microsoft.PowerShell.Commands.ComputerChangeInfo]$computerChangeInfo = Add-Computer -ComputerName $env:COMPUTERNAME -DomainName $domainToJoin -Credential $credential -OUPath $ouPath -Force -PassThru

    if ($computerChangeInfo.HasSucceeded) {
        Write-Output "Successfully joined the $domaintoJoin domain"

        Write-Output "Attempting to add $domainJoinUsername to the administrators group..."
        if ([string]::IsNullOrEmpty($domainJoinUsername)) 
        { 
            $results = "Username not provided"
        }
        else
        {
            $results = Invoke-Expression -Command "net localgroup administrators $domainJoinUsername /add"
            $results += "`n List members of local VM Administrators Group:"
            $results += Invoke-Expression -Command "net localgroup administrators"
        }
        Write-Output "Result: $results"
    }
    else {
        Write-Error "Failed to join $env:COMPUTERNAME to $domaintoJoin domain"
    }
}
