param
(
    [Parameter(Mandatory=$true, HelpMessage="The location of the factory configuration files")]
    [string] $ConfigurationLocation
)

#resolve any relative paths in ConfigurationLocation 
$ConfigurationLocation = (Resolve-Path $ConfigurationLocation).Path

$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath

$labsList = Join-Path $ConfigurationLocation "Labs.json"
$labInfo = ConvertFrom-Json -InputObject (gc $labsList -Raw)
$sortedLabList = $labInfo.Labs | Sort-Object {$_.SubscriptionId}
Write-Output "Validating $($sortedLabList.Count) labs from Labs.json"


$sortedLabList | Group-Object -Property SubscriptionId,LabName | Where-Object {$_.Count -gt 1} | 
    ForEach-Object { 
        $labName = $_.Group[0].LabName
        $subId = $_.Group[0].SubscriptionId
        $dupCount = $_.Count
        Write-Error "Lab named $labName in subscription $subId is listed $dupCount times in Labs.json" 
    }

# Iterate through all the labs
foreach ($selectedLab in $sortedLabList){

    # Get the list of images in the current lab
    SelectSubscription $selectedLab.SubscriptionId
    $selectedLabRG = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $selectedLab.LabName}).ResourceGroupName

    if($selectedLabRG)
    {
        Write-Output ("Found existing lab named $($selectedLab.LabName) in subscription $($selectedLab.SubscriptionId)")
    }
    else
    {
        Write-Error ("Unable to find an existing lab named $($selectedLab.LabName) in subscription $($selectedLab.SubscriptionId)")
    }

    $goldenImagesFolder = Join-Path $ConfigurationLocation "GoldenImages"
    $goldenImageFiles = Get-ChildItem $goldenImagesFolder -Recurse -Filter "*.json" | Select-Object FullName
    foreach ($labImagePath in $selectedLab.ImagePaths){
        $filePath = Join-Path $goldenImagesFolder $labImagePath
        $matchingImages = $goldenImageFiles | Where-Object {$_.FullName.StartsWith($filePath,"CurrentCultureIgnoreCase")}
        if($matchingImages.Count -eq 0){
            Write-Error "The Lab named $($selectedLab.LabName) with SubscriptionId $($selectedLab.SubscriptionId) contains an ImagePath entry $labImagePath which does not point to any existing files in the GoldenImages folder."
        }
    }
}
