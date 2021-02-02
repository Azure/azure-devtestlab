# Imports custom role named Az Labs Custom Contributor Role at the subscription level.  
# Once imported, this role can then be assigned to teachers.  This role gives finer grained control over the permissions teachers are granted when managing labs.
$index = (Get-Content -path ".\AzLabsCustomContributorRole.json" -Raw).IndexOf("{Your Sub Id}")
if ($index -eq -1) {
    New-AzRoleDefinition -InputFile ".\AzLabsCustomContributorRole.json"
}
else {
    Write-Error -Message "You must replace {Your Sub Id} in AzLabsCustomContributorRole.json with your Azure subscription id."
}

