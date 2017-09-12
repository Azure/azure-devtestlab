#.\GenerateImageList.ps1 -ImageDefinitionsLocation ..\ImageFactoryConfiguration\GoldenImages -ArtifactLocations ("..\Artifacts", "..\ImageFactoryConfiguration\Artifacts") -OutputFile ..\..\Imagelist.htm
param
(
    [Parameter(Mandatory=$true, HelpMessage="The location of the image definitions (JSON ARM Templates) for DevTest Labs Custom Images")]
    [string] $ImageDefinitionsLocation,

    [Parameter(Mandatory=$true, HelpMessage="The location of the Artifact Inventories (either a string or array of strings)")]
    [Array] $ArtifactLocations,
    
    [Parameter(Mandatory=$true, HelpMessage="Output location for the list of images in HTML format")]
    [string] $OutputFile
)

function Get-ImageName
{
    [CmdletBinding()]
    param(
        $imagePathValue
    )    

    $splitImagePath = $imagePathValue.Split('\')
    if($splitImagePath.Length -eq 1){
        #the image is directly in the GoldenImages folder. Just use the file name as the image name.
        $newimagename = $splitImagePath[0]
    }
    else {
        #this image is in a folder within GoldenImages. Name the image <FolderName>  <fileName> with <FolderName> set to the name of the folder that contains the image
        $segmentCount = $splitImagePath.Length
        $newimagename = $splitImagePath[$segmentCount - 2] + "  " + $splitImagePath[$segmentCount - 1]
    }

    #clean up some special characters in the image name and stamp it with todays date
    $newimagename = $newimagename.Replace(".json", "").Replace(".", "_")

    return $newimagename
}

# set up the beginning of the html
$output = @"
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
    <script src="https://code.jquery.com/jquery-3.1.1.min.js"></script>
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>
"@
$output += '<script>$(function () { $(''[data-toggle="tooltip"]'').tooltip(); $(''a[data-toggle="tooltip"]'').click(function(){$(''tr'').removeClass(''info'');$(''tr td a[name='' + $(this).text() + '']'').parent().parent().addClass(''info''); })});</script>'
$output += @"
<style>
   .icon {
     width: 20px; 
     height: 20px; 
     margin-right: 10px;
   }
   .mainDiv {
     padding:20px 40px 20px 40px;
   }
   table thead tr {
     background-color:yellow;
   }
   .cellNowrap {
     font-size:smaller;
     white-space:nowrap;
   }

</style>
</head>
<body>
    <div class="mainDiv">
        <h1>Custom Image Definitions</h1>
        <table class="table table-striped table-responsive table-condensed container">
            <thead>
                <tr>
                    <th>Image Name</th>
                    <th>Details</th>
                    <th>Artifacts Applied</th>
                </tr>
            </thead>
"@

# resolve path for image definitions
$imageListLocation = (Resolve-Path $ImageDefinitionsLocation).Path

# get a list of artifacts & load up names/descriptions into a hashtable for reference later
$artifactDescriptions = @{}
$artifactLocationList = $ArtifactLocations | ForEach-Object {$_ | Resolve-Path | Get-ChildItem -Recurse -Filter "ArtifactFile.json"}
foreach ($artifactLocation in $artifactLocationList) {
    $ArtifactDetails = (Get-Content $artifactLocation.FullName -Raw | ConvertFrom-Json)
    $artifactDescriptions.add($artifactLocation.Directory.Name, @{Description=$ArtifactDetails.description; IconURI=$ArtifactDetails.iconUri; TargetOS=$ArtifactDetails.targetOsType})
}

# get the list of labs from the json file
$files = Get-ChildItem $imageListLocation -Recurse -Filter "*.json"

foreach ($file in $files)
{
    # start this grouping
    $output += "<tr>"

    # Pull out the interesting bits from the ARM template (json format)
    $imageDetails = ConvertFrom-Json -InputObject (gc $file.FullName -Raw)
    $imageDescription = $imageDetails.resources[0].properties.notes
    $baseImageOffer = $imageDetails.resources[0].properties.galleryImageReference.offer
    $baseImageSku = $imageDetails.resources[0].properties.galleryImageReference.sku
    $baseImageType = $imageDetails.resources[0].properties.galleryImageReference.osType
    $artifacts = $imageDetails.resources[0].properties.artifacts

    # Get the name of the image first
    $imagePath = $file.FullName.Substring($imageListLocation.Length + 1)
    $imagename = Get-ImageName $imagePath
    if ($baseImageType -eq "Linux") {
        $labelType = "label-success"
    }
    else {
        $labelType = "label-primary"
    }
    $output += "<td><small><b>$imagename </b></small><div class=""label $labelType"">$baseImageType</div></td>"

    # Next, include image description
    $output += "<td>$imageDescription <div><small><b>BASE: </b> $baseImageOffer, $baseImageSku</small></div></td>"

    # And the list of artifacts
    $output += "<td class=""cellNowrap"">"
    if ($artifacts.Count -gt 0) {
        foreach ($artifact in $artifacts) {
            $artifactsplit = $artifact.artifactId.Split("'")
            # the name of the artifact is the 2nd to last item in the list
            $artifactName = $artifactsplit[$artifactsplit.Length-2]
            $artifactDescription = $artifactDescriptions.$artifactName.Description
            $output += "<div><a data-toggle=""tooltip"" data-placement=""left"" title=""$artifactDescription"" href=""#$artifactName"">$artifactName</a></div>"
        }
    }

    # Close the remaining all the tags
    $output += "</td></tr>"

}

$output += @"
        </table>
        <hr />
        <h1>Artifact Inventory</h1>
        <table class="table table-striped table-responsive table-condensed container">
            <thead>
                <tr>
                    <th>Artifact Name</th>
                    <th>Artifact Description</th>
                    <th>Target OS</th>
                </tr>
            </thead>
"@

foreach($artifact in ($artifactDescriptions.GetEnumerator() | Sort-Object Name)) {
    # start this grouping
    $output += "<tr>"
    $output += ("<td><img src=""" + $artifact.Value.IconURI + """ class=""icon"" /><a name=""" + $artifact.Name + """></a>" + $artifact.Name + "</td>")
    $output += ("<td>" + $artifact.Value.Description + "</td>")
    $output += ("<td>" + $artifact.Value.TargetOS + "</td>")
    

    # Close the remaining all the tags
    $output += "</tr>"
}

$output += @"
        </table>
    </div>
</body>
</html>
"@

Set-Content -Value $output -Path $OutputFile
