Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

function Get-DocInventory([string]$siteUrl) {
$site = New-Object Microsoft.SharePoint.SPSite $siteUrl
foreach ($web in $site.AllWebs) {
foreach ($list in $web.Lists) {
if ($list.BaseType -ne “DocumentLibrary”) {
continue
}

foreach ($item in $list.Items) {

#split document id value
$dIDVal = $item["_dlc_DocIdUrl"]
$dIDParts = $dIDVal -split ",",0,"SimpleMatch"

#split topic value
$topicVal = $item["Topic"]
$topicParts = $topicVal -split "|",0,"SimpleMatch"

#split Subtopic value
$topicSubVal = $item["Subtopic"]
$topicSubParts = $topicSubVal -split "|",0,"SimpleMatch"


#get managed metadata field Department value
[Microsoft.SharePoint.Taxonomy.TaxonomyFieldValueCollection]$MMSDepartmentColl = $item["ENetDepartment"]
 
#Concatenate each term in the value Department collection
$MMSDepartmentTerms=""
Foreach ($MMSDepartmentValue in $MMSDepartmentColl)
{
    if($MMSDepartmentValue.label -ne $null)
    {
        $MMSDepartmentTerms+=$MMSDepartmentValue.label+"; "
    }
}


#get managed metadata field Role value
[Microsoft.SharePoint.Taxonomy.TaxonomyFieldValueCollection]$MMSRoleColl = $item["ENetRole"]
 
#Concatenate each term in the value Epic Application collection
$MMSRoleTerms=""
Foreach ($MMSRoleValue in $MMSRoleColl)
{
    if($MMSRoleValue.label -ne $null)
    {
        $MMSRoleTerms+=$MMSRoleValue.label+"; "
    }
}


#get managed metadata field Epic Application value
[Microsoft.SharePoint.Taxonomy.TaxonomyFieldValueCollection]$MMSEpicApplicationColl = $item["EpicApplication"]
 
#Concatenate each term in the value Epic Application collection
$MMSEpicApplicationTerms=""
Foreach ($MMSEpicApplicationValue in $MMSEpicApplicationColl)
{
    if($MMSEpicApplicationValue.label -ne $null)
    {
        $MMSEpicApplicationTerms+=$MMSEpicApplicationValue.label+"; "
    }
}


#get managed metadata Location value powershell
[Microsoft.SharePoint.Taxonomy.TaxonomyFieldValueCollection]$MMSLocationColl = $item["ENetAudience"]
 
#Concatenate each term in the value Location collection
$MMSLocationTerms=""
Foreach ($MMSLocationValue in $MMSLocationColl)
{
    if($MMSLocationValue.label -ne $null)
    {
        $MMSLocationTerms+=$MMSLocationValue.label+"; "
    }
}


#physical url
$docPath = $web.Url + "/" + $item.Url

$data = @{
"Name" = $item["Name"]
"ListItemID" = $item.ID
"Site" = $site.Url
"Web" = $web.Url
"List" = $list.Title
"PhysicalURL" = $docPath
"Title" = $item.Title
"DocumentID" = $dIDParts[1]
"DocumentURL" = $dIDParts[0]
"Topic" = $topicParts[0]
"Subtopic" = $topicSubParts[0]
"LegacyID" = $item["Legacy ID"]
"EpicApplication" = $MMSEpicApplicationTerms
"ENetAudience" = $MMSLocationTerms
"ENetDepartment" = $MMSDepartmentTerms
"ENetRole" = $MMSRoleTerms
"ENetKeywords" = $item["ENetKeywords"]
"ENetDescription" = $item["ENetDescription"]
}
New-Object PSObject -Property $data
}
}
$web.Dispose();
}
$site.Dispose()
}

#Get-DocInventory "http://excellian.net" | Select-Object Name,Title,LegacyID,Topic,Subtopic,Web,List,ListItemID,DocumentID,DocumentURL,PhysicalURL,ENetAudience,EpicApplication,ENetDepartment,ENetRole,ENetKeywords,ENetDescription | Out-GridView
Get-DocInventory "http://excellian.net" | Select-Object Name,Title,LegacyID,Topic,Subtopic,Web,List,ListItemID,DocumentID,DocumentURL,PhysicalURL,ENetAudience,EpicApplication,ENetDepartment,ENetRole,ENetKeywords,ENetDescription | Export-Csv -NoTypeInformation -Path "E:\ENet_Document_Detail_Report.csv"