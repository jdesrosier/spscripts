	Param(

		# URL of SharePoint subsite
		[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
		[string]$webUrl,

		# Name used for document library
		[Parameter(Mandatory=$true, Position=1)]
		[string]$LibraryName,

		# Description used for document library
		[Parameter(Mandatory=$false, Position=2)]
		[string]$Description,

		# Template used to create document library
		[Parameter(Mandatory=$false, Position=3)]
		[string]$LibraryTemplate,

		# Site value used in termstore
		[Parameter(Mandatory=$true, Position=4)]
		[string]$SiteTSV,

		# Service value used in termstore
		[Parameter(Mandatory=$false, Position=5)]
		[string]$ServiceTSV,

		# Topic value used in termstore
		[Parameter(Mandatory=$true, Position=6)]
		[string]$TopicTSV

	)

	Function Create-DocLibrary
	{
		# --------------------------------------------------------------------------
		# Set default values on optional parameters
		# --------------------------------------------------------------------------

		if([string]::IsNullOrEmpty($LibraryTemplate))
		{
			$LibraryTemplate = [Microsoft.SharePoint.SPListTemplateType]::DocumentLibrary
		}

		if([string]::IsNullOrEmpty($ServiceTSV))
		{
			# Set Service to use the sample value of site metadata
			$ServiceTSV = $SiteTSV
		}		

		# --------------------------------------------------------------------------
		#  Get SharePoint subsite and library objects
		# --------------------------------------------------------------------------

		Start-SPAssignment -Global 

		$spWeb = Get-SPWeb -Identity $webUrl    
		$spListCollection = $spWeb.Lists  
		$spLibrary = $spListCollection.TryGetList($LibraryName)

		# --------------------------------------------------------------------------
		# Create document library
		# --------------------------------------------------------------------------

		if($spLibrary -ne $null) {

			Write-Host -f Yellow "Library $LibraryName already exists in the site. Only modifications will be applied."

		} else {       

			$spListCollection.Add($LibraryName, $Description, $LibraryTemplate)
			$spLibrary = $spWeb.GetList($spWeb.ServerRelativeUrl+"/"+"$LibraryName")

			Write-Host -f Green "New document library created"

		}

     		# --------------------------------------------------------------------------
		# Set document library content types  
		# --------------------------------------------------------------------------

		$SPSite = Get-SPSite $webUrl.Substring(0,$webUrl.LastIndexOf('/'))
		$spLibrary.ContentTypesEnabled = $true
		$spLibrary.Update()

		$AKNDocCT = $SPSite.RootWeb.ContentTypes["AKN Document"]
      		
		# Check to see if content type exists already
		if ($spLibrary.ContentTypes["AKN Document"] -eq $null)
       	 	{

			# Add akn document content type in library
			$ct = $spLibrary.ContentTypes.Add($AKNDocCT)
		}

		$DocCT = $spLibrary.ContentTypes["Document"]

		# Check to see if content type exists
      		if ($DocCT -ne $null)
		{
            		
			#Remove document content type from library
			$spLibrary.ContentTypes.Delete($DocCT.Id)

		}

		Write-Host -f Green "Content types set"

		# -------------------------------------------------------------------------- 
		# Set major revision setting
		# --------------------------------------------------------------------------
	
		$maxMajorRevions = 3			
		$spLibrary.MajorVersionLimit = $maxMajorRevions
		$spLibrary.Update()

		Write-Host -f Green "Max major revisions set to:" $maxMajorRevions

		# -------------------------------------------------------------------------- 
		# Disable folder creation in library
		# --------------------------------------------------------------------------

		$spLibrary.EnableFolderCreation = $false
		$spLibrary.Update()

		Write-Host -f Green "Folder creation disable for this document library"

		# --------------------------------------------------------------------------
		# Set column default values
		# --------------------------------------------------------------------------

		$session = new-object Microsoft.SharePoint.Taxonomy.TaxonomySession($SPSite)

		# Get the term store instance
		$termstore = $session.TermStores["Managed Metadata Service"]

		# Get the Term Group using the Name
		$group = $termstore.Groups | Where-Object { $_.Name -eq "Site Collection"}

		# Get the TermSet using the TermSet name
		$termSet = $group.TermSets | Where-Object { $_.Name -eq "AKNSource" }
		$terms = $termSet.GetAllTerms()

		$columnDefaults = New-Object Microsoft.Office.DocumentManagement.MetadataDefaults($spLibrary)

		# Site column
		$siteVal = $terms | ?{$_.Name -eq $SiteTSV}
		$siteValStr = "-1;#" + $siteVal.Name + "|" + $siteVal.Id.ToString()
		Set-DefaultColumnValue "AKNSite" $siteValStr

		# Service column
		$serviceVal = $terms | ?{$_.Name -eq $ServiceTSV}
		$serviceValStr = "-1;#" + $serviceVal.Name + "|" + $serviceVal.Id.ToString()
		Set-DefaultColumnValue "Service12" $serviceValStr

		# Topic column
		$topicVal = $terms | ?{$_.Name -eq $TopicTSV}
		$topicValStr = "-1;#" + $topicVal.Name + "|" + $topicVal.Id.ToString()
		#Set-DefaultColumnValue "Topic" $topicValStr
		$f = $spLibrary.Fields["Topic"]
		$columnDefaults = New-Object Microsoft.Office.DocumentManagement.MetadataDefaults($spLibrary)
		$columnDefaults.SetFieldDefault($spLibrary.RootFolder, "Topic", $topicValStr)
		#$f.DefaultValue = $topicValStr
		$columnDefaults.Update()

		# Subtopic column
		$field = $spLibrary.Fields["Subtopic"]
		
		# Get the field ref
		[Microsoft.SharePoint.Taxonomy.TaxonomyField]$field = $spLibrary.Fields["Subtopic"]

		# Update the SspId
		$field.SspId = $termstore.Id
		$field.TermSetId = $termSet.Id

		# Map the term value
		$field.AnchorId = $topicVal.Id

		# Update the field
		$field.Update()

		Write-Host -f Green "Default values set on columns"
		
		# --------------------------------------------------------------------------
		# Document library view modifications
		# --------------------------------------------------------------------------
		
		$view = $spLibrary.DefaultView

		Add-ViewColumns("Topic")
		Add-ViewColumns("Subtopic")

		# Set the view: group by and order by settings
		$view.Query = "<GroupBy Collapse=""FALSE"" GroupLimit=""100""> <FieldRef Name=""Subtopic"" Ascending=""FALSE""/> </GroupBy> <OrderBy> <FieldRef Name=""Modified"" Ascending=""FALSE"" /></OrderBy>"
    		$view.Update()

		Write-Host -f Green "View modifications completed"

		Stop-SPAssignment -Global  
	}
	



Function Set-DefaultColumnValue([string]$column, [string]$columnVal)
{
	#old
	#$f = $spLibrary.Fields[$column]
	#$f.DefaultValue = $columnVal
	#$f.Update()

	#new
	
	$columnDefaults.SetFieldDefault($spLibrary.RootFolder, $column, $columnVal)
	$columnDefaults.Update()
}

Function Add-ViewColumns([string]$column)
{
	
	# Add column to view
	if(!$view.ViewFields.ToStringCollection().Contains($column))
	{
			
		$view.ViewFields.add($column)
		$view.Update()

	}
}
Create-DocLibrary