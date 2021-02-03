# Imports custom role named AzLabsCustomContributorRole at the subscription level.  
# Once imported, this role can then be assigned to teachers at the lab level.  
# This role gives fine grained control of the permissions that teachers are granted when managing labs.
$index = (Get-Content -path ".\AzLabsCustomContributorRole.json" -Raw).IndexOf("{Your Sub Id}")
if ($index -eq -1) {
    New-AzRoleDefinition -InputFile ".\AzLabsCustomContributorRole.json"
}
else {
    Write-Error -Message "You must replace {Your Sub Id} in AzLabsCustomContributorRole.json with your Azure subscription id."
}

