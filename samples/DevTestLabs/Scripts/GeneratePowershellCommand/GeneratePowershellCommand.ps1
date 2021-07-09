### Takes a file path to an artifactFile and spits out a parameterized powerhsell command
param (
    [Parameter(Mandatory=$true, HelpMessage="The path of an artifactFile")]
    [string] $file
)

if ($false -eq (Test-Path $file)) {
    throw "File does not exist '$file'"
}

$json = Get-Content -Path $file -Raw
$config = ConvertFrom-Json $json

$parameters = $config.parameters

$command = "./your-file.ps1 "

foreach($property in $parameters.PSObject.Properties)
{
    # Access the name of the property
    $parameterName = $property.Name

    if ([string]::IsNullOrEmpty($parameterName)) {
        throw "Missing name property on a parameter"
    }

    # Access the value of the property
    $parameter = $property.Value
    $type = $parameter.type

    if ([string]::IsNullOrEmpty($type)) {
        throw "Missing type property on parameter '$parameterName'"
    }

    if ($type -eq "string") {
        $result = "-$parameterName ''', parameters('$parameterName'), ''' "
    } elseif ($type -eq 'int') {
        $result = "-$parameterName ', parameters('$parameterName'), ' "
    } elseif ($type -eq "securestring") {
        $result = "-$parameterName `$(if (`$false -eq [string]::IsNullOrEmpty(''', parameters('$parameterName'), ''')) { (ConvertTo-SecureString ''', parameters('$parameterName'), ''' -AsPlainText -Force) } else { `$null }) "
    } elseif ($type -eq "bool") {
        $result = "-" + $parameterName + ":$', parameters('$parameterName'), ' "
    } else {
        throw "parameter type not supported '$type' for '$parameterName'"
    }

    $command += $result
}


$prefix = '[concat(''powershell.exe -ExecutionPolicy bypass \"'
$postfix = '\"'')]'

$result = $prefix + $command + $postfix

Write-Host $result