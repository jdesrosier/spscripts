Param(

		#Example: batchlinks -siteUrl "http://spsstg01.allina.com" -webName "is" -libraryName "ITIL Links" -manifestFile "e:\SPDocBatching\batches\is\itil_links.csv"

		# URL path to SharePoint site collection
		[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
		[string]$siteUrl,

		# URL path of SharePoint subsite (do not include domain and site collection)
		[Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
		[string]$webName,

		# Name of the link library
		[Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$true)]
		[string]$libraryName,

		# Path and name of link manifest
		[Parameter(Mandatory=$true, Position=3, ValueFromPipeline=$true)]
		[string]$manifestFile

	)

# Global variables
$listName= $libraryName
$linkManifest= $manifestFile

# Open SharePoint list
$siteCollection= $siteUrl
$webSite= $webName
$webUrl = $siteCollection + "/" + $webSite 
$listPath= $webUrl + "/Lists/" + $listName
$spWeb = Get-SPWeb $webUrl 
$spData = $spWeb.GetList($listPath)

# Get data from link manifest CSV file 
$FileExists = (Test-Path $linkManifest -PathType Leaf) 
if ($FileExists) { 
   Write-Host -f Yellow "Loading $linkManifest for processing..." 
   $tblData = Import-CSV $linkManifest -Delimiter ';'
} else { 
   Write-Host -f Red "$linkManifest not found - stopping import!" 
   exit 
}

# Loop through links add to link list

Write-Host -f Yellow "Add items to SharePoint list: $listName"

foreach ($row in $tblData) 
{ 
    # Title,Link,AKN Site,Topic,Subtopic,AKN Description
    $titleVal = $row."Title"
    $linkVal = $row."Link"
    $siteVal = $row."AKN Site"
    $topicVal = $row."Topic"
    $subtopicVal = $row."Subtopic"
    $descVal = $row."AKN Description"
    $siteTermValStr = ""
    $topicTermValStr = ""
    $subtopicTermValStr = ""
    
    # Parse link column (URL,Description)
    $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue;   
    $urlValue.Url = $linkVal 
    $urlValue.Description = $titleVal 
   
    # Set Managed Metadata Values

    # Get the Term from Term store
    $site = Get-SPWeb $siteCollection
    $TaxonomySession = Get-SPTaxonomySession -Site $site.Site
    $TermStore = $TaxonomySession.TermStores["Managed Metadata Service"]
    $TermGroup = $TermStore.Groups["Site Collection"]
    $TermSet = $TermGroup.TermSets["AKNSource"]
    $terms = $termSet.GetAllTerms()

    # AKN Site Column
	Write-Host -f yellow "siteVal: $siteVal | topicVal: $topicVal | subtopicVal: $subtopicVal"
    if($siteVal)
    {
        $siteTermVal = $terms | ?{$_.Name -eq $siteVal}
        $siteTermValStr = "-1;#" + $siteTermVal.Name + "|" + $siteTermVal.Id.ToString()
    }

    # Topic Column
    if($topicVal)
    {
        $topicTermVal = $terms | ?{$_.Name -eq $topicVal}
        $topicTermValStr = "-1;#" + $topicTermVal.Name + "|" + $topicTermVal.Id.ToString()
    }

    # Subtopic Column
    if($subtopicVal)
    {
        $subtopicTermVal = $terms | ?{$_.Name -eq $subtopicVal}
        $subtopicTermValStr = "-1;#" + $subtopicTermVal.Name + "|" + $subtopicTermVal.Id.ToString()
    }

    # Add a new link item to the list
    Write-Host -f cyan "Adding entry for: $titleVal" 
    $spItem = $spData.AddItem() 
    $spItem["Title"] = $titleVal
    $spItem["Link"] = [Microsoft.SharePoint.SPFieldUrlValue]$urlValue
    $spItem["AKN Site"] = $siteTermValStr
    $spItem["Topic"] = $topicTermValStr
    $spItem["Subtopic"] = $subtopicTermValStr
    $spItem["AKN Description"] = $descVal
    $spItem.Update() 
}

Write-Host -f Green "Upload Complete"

$spWeb.Dispose()