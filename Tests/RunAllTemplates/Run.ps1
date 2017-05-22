# ----------------------------------------------------------------------------------
#
# Copyright Microsoft Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------
$myPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path;

$ResourceGroupName = "myRG234"
$Location ="southeastasia"


$allTemplateFolders = "$myPath\..\..\ARMTemplates" | Get-ChildItem  | where {$_.PsIsContainer} 

New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force

$allTemplateFolders | foreach {

    $template = ($_ | Get-ChildItem | where {$_.Name -eq "azuredeploy.json"} | select FullName).FullName
    $params = ($_ | Get-ChildItem | where {$_.Name -eq "azuredeploy.parameters.json"} | select FullName).FullName

    "Running $_ ... " | Write-Host -ForegroundColor Green

    New-AzureRmResourceGroupDeployment -Name $_ -ResourceGroupName $ResourceGroupName -TemplateFile $template -TemplateParameterFile $params -Verbose
    }
