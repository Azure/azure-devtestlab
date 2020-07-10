<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script start all the VMs in the current Lab. It leaves enough time for the domain join before shutting them down.
#>

###################################################################################################
try {

    $ErrorActionPreference = "Stop"

    . ".\Utils.ps1"

    Write-Output "Importing AzLab Module"
    Import-AzLabModule

    $templateVm = Get-AzLabCurrentTemplateVm

    Write-Output "Getting information on the currently running Template VM"

    $lab = $templateVm | Get-AzLabForVm

    Write-LogFile "Starting all VMs"
    $templateVms = Get-AzLabVm -Lab $lab

    $jobs = @()
    $templateVms | ForEach-Object {
        $sb = {
            Import-AzLabModule
            Start-AzLabVm -Vm $Using:_
        }
        $jobs += Start-Job -ScriptBlock $sb
    }

    Receive-Job -Job $jobs -Wait

    Write-LogFile "Waiting for the VMs to join the domain"
    Start-Sleep -Seconds 180

    Write-LogFile "Stopping all VMs"

    $jobs = @()
    $templateVms | ForEach-Object {
        $sb = {
            Import-AzLabModule
            Stop-AzLabVm -Vm $Using:_
        }
        $jobs += Start-Job -ScriptBlock $sb
    }

    Receive-Job -Job $jobs -Wait

    $ExitCode = 0
}

catch
{
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Error "`nERROR: $message"
    }

    Write-Error "`nThe script failed to run.`n"

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    $ExitCode = -1
}

finally {

    Write-Output "Exiting with $ExitCode" 
    exit $ExitCode
}