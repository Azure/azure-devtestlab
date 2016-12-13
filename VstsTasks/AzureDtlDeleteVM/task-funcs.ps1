function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Error "`n$message"
    }
}

function Show-InputParameters
{
    [CmdletBinding()]
    param(
    )

    Write-Host "Task called with the following parameters:"
    Write-Host "  ConnectedServiceName = $ConnectedServiceName"
    Write-Host "  LabVMId = $LabVMId"
}

function Invoke-AzureDtlTask
{
    [CmdletBinding()]
    param(
        $LabVMId
    )

    $labVMParts = $LabVMId.Split('/')
    $labVMName = $labVMParts.Get($labVMParts.Length - 1)
    $labName = $labVMParts.Get($labVMParts.IndexOf('labs') + 1)

    Write-Host "Deleting Lab VM '$labVMName' from Lab '$labName'"
    Remove-AzureRmResource -ResourceId "$LabVMId" -Force | Out-Null
}
