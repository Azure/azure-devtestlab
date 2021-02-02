$index = (Get-Content -path ".\AzLabsCustomContribRole.json" -Raw).IndexOf("{Your Sub Id}")
if ($index -eq -1) {
    New-AzRoleDefinition -InputFile ".\AzLabsCustomContribRole.json"
}
else {
    Write-Error -Message "You must replace {Your Sub Id} in AzLabsCustomContribRole.json with your Azure subscription id."
}

