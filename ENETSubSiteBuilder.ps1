﻿Param(

		<#
            Examples: 

            # Production
            ./ENETSubSiteBuilder -webTitle "Test Sub Site" -webName "EnetSubSite" -siteCollectionUrl "http://excellian.net" -siteGUID "118f62a4-8b3b-4c57-9ad5-3cb1a4f30aad"

        #>

		# Title of SharePoint subsite
		[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
		[string]$webTitle,

		# URL path of SharePoint subsite (do not include domain and site collection)
		[Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
		[string]$webName,

		# URL of SharePoint site collection
		[Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$true)]
		[string]$siteCollectionUrl,

		# Site value used in termstore
		[Parameter(Mandatory=$true, Position=3, ValueFromPipeline=$true)]
		[string]$siteGUID

	)


#***********************************************************************
# 
#  Create Document Library
#
#***********************************************************************

Function Create-DocLibrary([string]$libraryName, [string]$libraryDesc, [string]$topicGUID)
{
    # --------------------------------------------------------------------------
    # Set default values on optional parameters
    # --------------------------------------------------------------------------

    # Set the List template to Document Library
    $libraryTemplate = [Microsoft.SharePoint.SPListTemplateType]::DocumentLibrary

    # Set Service to use the sample value of site metadata
    $serviceGUID = $siteGUID

    # Append documents to library name
    Write-Host ("LibaryName: {0}" -f $libraryName)
    Write-Host ("SiteID: {0}" -f $siteGUID)
    Write-Host ("TopicID: {0}" -f $topicGUID)

    # --------------------------------------------------------------------------
    #  Get SharePoint subsite and library objects
    # --------------------------------------------------------------------------

    Start-SPAssignment -Global 

    $spWeb = Get-SPWeb -Identity $webUrl    
    $spListCollection = $spWeb.Lists  
    $spContainer = $spListCollection.TryGetList($libraryName)

    # --------------------------------------------------------------------------
    # Create document library
    # --------------------------------------------------------------------------

    if($spContainer -ne $null) {

        Write-Host -f Yellow "Library $libraryName already exists in the site. Only modifications will be applied."

    } else {       

        $spListCollection.Add($libraryName, $libraryDesc, $libraryTemplate)
        $spContainer = $spWeb.GetList($spWeb.ServerRelativeUrl+"/"+"$libraryName")

        Write-Host "New document library created: $libraryName" -ForegroundColor Green

    }

    # --------------------------------------------------------------------------
    # Set document library content types  
    # --------------------------------------------------------------------------

    #$spSite = Get-SPSite $webUrl.Substring(0,$webUrl.LastIndexOf('/'))
    $spSite = Get-SPSite $siteCollectionUrl
    $spContainer.ContentTypesEnabled = $true
    $spContainer.Update()

    $dtName = 'ENet Document'

    $ENETDocCT = $spSite.RootWeb.ContentTypes[$dtName]
        
    # Check to see if content type exists already
    if ($spContainer.ContentTypes[$dtName] -eq $null)
        {

        # Add akn document content type in library
        $ct = $spContainer.ContentTypes.Add($ENETDocCT)
    }

    $DocCT = $spContainer.ContentTypes["Document"]

    # Check to see if content type exists
        if ($DocCT)
    {
                
        #Remove document content type from library
        $spContainer.ContentTypes.Delete($DocCT.Id)

    }

    Write-Host -f Green "Content types set"

    # -------------------------------------------------------------------------- 
    # Set major revision setting
    # --------------------------------------------------------------------------

    $maxMajorRevions = 12			
    $spContainer.MajorVersionLimit = $maxMajorRevions
    $spContainer.Update()

    Write-Host -f Green "Max major revisions set to:" $maxMajorRevions

    # -------------------------------------------------------------------------- 
    # Disable folder creation in library
    # --------------------------------------------------------------------------

    $spContainer.EnableFolderCreation = $false
    $spContainer.Update()

    Write-Host "Folder creation disable for this document library" -ForegroundColor Green

    # --------------------------------------------------------------------------
    # Set column default values
    # --------------------------------------------------------------------------

    $session = new-object Microsoft.SharePoint.Taxonomy.TaxonomySession($spSite)

    # Get the term store instance
    $termstore = $session.TermStores["Managed Metadata Service"]

    # Get the Term Group using the Name
    $group = $termstore.Groups | Where-Object { $_.Name -eq "Excellian.net"}

    # Get the TermSet using the TermSet name
    $termSet = $group.TermSets | Where-Object { $_.Name -eq "ExcellianSource" }
    $terms = $termSet.GetAllTerms()

    $columnDefaults = New-Object Microsoft.Office.DocumentManagement.MetadataDefaults($spContainer)

    # Site column
    $siteVal = $terms | ?{$_.Id -eq $siteGUID}
    $siteValStr = "-1;#" + $siteVal.Name + "|" + $siteVal.Id.ToString()
    Set-DefaultColumnValue "ENetSite" $siteValStr

    # Service column
    #$serviceVal = $terms | ?{$_.Name -eq $serviceGUID}
    #$serviceValStr = "-1;#" + $serviceVal.Name + "|" + $serviceVal.Id.ToString()
    #Set-DefaultColumnValue "Service12" $serviceValStr
    if ($topicGUID)
    {
        # Topic column
        $topicVal = $terms | ?{$_.Id -eq $topicGUID}
        $topicValStr = "-1;#" + $topicVal.Name + "|" + $topicVal.Id.ToString()
        #Set-DefaultColumnValue "ExcellianTopic" $topicValStr
        $f = $spContainer.Fields["Topic"]
        $columnDefaults = New-Object Microsoft.Office.DocumentManagement.MetadataDefaults($spContainer)
        $columnDefaults.SetFieldDefault($spContainer.RootFolder, "ENetTopic", $topicValStr)
        #$f.DefaultValue = $topicValStr
        $columnDefaults.Update()
        
        # Update field MMS starting point
        [Microsoft.SharePoint.Taxonomy.TaxonomyField]$field = $spContainer.Fields["Topic"]
        # Update the SspId
        $field.SspId = $termstore.Id
        $field.TermSetId = $termSet.Id

        # Map the term value
        $field.AnchorId = $siteVal.Id
        $field.Update()

        # Subtopic column
        $field = $spContainer.Fields["Subtopic"]
        
        # Get the field ref
        [Microsoft.SharePoint.Taxonomy.TaxonomyField]$field = $spContainer.Fields["Subtopic"]

        # Update the SspId
        $field.SspId = $termstore.Id
        $field.TermSetId = $termSet.Id

        # Map the term value
        $field.AnchorId = $topicVal.Id

        # Update the field
        $field.Update()
    }
    Write-Host "Default values set on columns" -ForegroundColor Green
    
    # --------------------------------------------------------------------------
    # Document library view modifications
    # --------------------------------------------------------------------------

    #Set View Name
    $viewTitle = "By Subtopic" #Title property

    #Get the View
    $view = $spContainer.Views[$ViewTitle]

    #Update the view
    if($view -eq $null)
    {

        #Add the column names from the ViewField property to a string collection
        $viewFields = New-Object System.Collections.Specialized.StringCollection
        $viewFields.Add("Type") > $null
        $viewFields.Add("LinkFilename") > $null
        $viewFields.Add("Title") > $null
        $viewFields.Add("Modified") > $null
        $viewFields.Add("Modified By") > $null
        $viewFields.Add("Topic") > $null
        $viewFields.Add("Subtopic") > $null

        #Query property
        $viewQuery = "<GroupBy Collapse='TRUE' GroupLimit='100'> <FieldRef Name='ENetSubtopic' Ascending='FALSE'/> </GroupBy> <OrderBy> <FieldRef Name='Modified' Ascending='FALSE' /> </OrderBy>"
        #RowLimit property
        $viewRowLimit = 100
        #Paged property
        $viewPaged = $true
        #DefaultView property
        $viewDefaultView = $true

        #Create the view in the destination list
        $newview = $spContainer.Views.Add($viewTitle, $viewFields, $viewQuery, $viewRowLimit, $viewPaged, $viewDefaultView)
    } else {
    $view.DefaultView
    $view.Update()
    }

    Write-Host -f Green "View modifications completed"

    Stop-SPAssignment -Global  
}
	
#***********************************************************************
# 
#  Create Link List
#
#***********************************************************************

Function Create-LinkList([string]$listName, [string]$listDesc, [string]$topicGUID)
{
    # --------------------------------------------------------------------------
    # Set default values on optional parameters
    # --------------------------------------------------------------------------

    # Set the List template to GenericList (Custom List)
    $listTemplate = [Microsoft.SharePoint.SPListTemplateType]::GenericList

    # Set Service to use the sample value of site metadata
    #$serviceGUID = $siteGUID

    # Append documents to library name
    $linkListName = $listName	
    #Write-Host ("LibaryName: {0}" -f $linkListName)
    #Write-Host ("SiteID: {0}" -f $siteGUID)
    #Write-Host ("TopicID: {0}" -f $topicGUID)

    # --------------------------------------------------------------------------
    #  Get SharePoint subsite and library objects
    # --------------------------------------------------------------------------

    Start-SPAssignment -Global 

    $spWeb = Get-SPWeb -Identity $webUrl    
    $spListCollection = $spWeb.Lists  
    $spContainer = $spListCollection.TryGetList($linkListName)

        

    # --------------------------------------------------------------------------
    # Create list
    # --------------------------------------------------------------------------

    if($spContainer) {

        Write-Host -f Yellow "The list $linkListName already exists in the site. Only modifications will be applied."

    } else {       

        $spListCollection.Add($linkListName, $listDesc, $listTemplate)



        $spContainer = $spWeb.GetList($spWeb.ServerRelativeUrl+"/lists/"+"$linkListName")


        Write-Host "New custom list created: $linkListName" -ForegroundColor Green

    }

    # --------------------------------------------------------------------------
    # Set custom list content types  
    # --------------------------------------------------------------------------

    $spSite = Get-SPSite $siteCollectionUrl
    $spContainer.ContentTypesEnabled = $true
    $spContainer.Update()

    $ENETDocCT = $spSite.RootWeb.ContentTypes["ENet Site Links"]
        
    # Check to see if content type exists already
    if ($spContainer.ContentTypes["ENet Site Links"] -eq $null)
        {

        # Add akn document content type in library
        $ct = $spContainer.ContentTypes.Add($ENETDocCT)
    }

    $DocCT = $spContainer.ContentTypes["Item"]

    # Check to see if content type exists
        if ($DocCT)
    {
                
        #Remove item content type from library
        $spContainer.ContentTypes.Delete($DocCT.Id)

    }

    Write-Host "Content types set" -ForegroundColor Green

    # --------------------------------------------------------------------------
    # Set column default values
    # --------------------------------------------------------------------------

    $session = new-object Microsoft.SharePoint.Taxonomy.TaxonomySession($spSite)

    # Get the term store instance
    $termstore = $session.TermStores["Managed Metadata Service"]

    # Get the Term Group using the Name
    $group = $termstore.Groups | Where-Object { $_.Name -eq "Excellian.net"}

    # Get the TermSet using the TermSet name
    $termSet = $group.TermSets | Where-Object { $_.Name -eq "ExcellianSource" }
    $terms = $termSet.GetAllTerms()

    # Site column
    $siteVal = $terms | ?{$_.Id -eq $siteGUID}
    $siteValStr = "-1;#" + $siteVal.Name + "|" + $siteVal.Id.ToString()
    $field = $spContainer.Fields["ENet Site"]
    $field.DefaultValue = $siteValStr
    $field.Update()

    if ($topicGUID)
    {
        # Topic column
        $topicVal = $terms | ?{$_.Id -eq $topicGUID}
        $topicValStr = "-1;#" + $topicVal.Name + "|" + $topicVal.Id.ToString()
        $field = $spContainer.Fields["Topic"]

        # Update the SspId
        $field.SspId = $termstore.Id
        $field.TermSetId = $termSet.Id

        # Map the term value
        $field.AnchorId = $siteVal.Id

        $field.DefaultValue = $topicValStr
        $field.Update()

        # Subtopic column
        $field = $spContainer.Fields["Subtopic"]
        
        # Get the field ref
        [Microsoft.SharePoint.Taxonomy.TaxonomyField]$field = $spContainer.Fields["Subtopic"]

        # Update the SspId
        $field.SspId = $termstore.Id
        $field.TermSetId = $termSet.Id

        # Map the term value
        $field.AnchorId = $topicVal.Id

        # Update the field
        $field.Update()
    }

    Write-Host -f Green "Default values set on columns"
    
    # --------------------------------------------------------------------------
    # Link List view modifications
    # --------------------------------------------------------------------------

    #Set View Name
    $viewTitle = "By Subtopic" #Title property

    #Get the View
    $view = $spContainer.Views[$ViewTitle]

    #Update the view
    if($view -eq $null)
    {
        if ($topicGUID -ne $null)
        {
            #Add the column names from the ViewField property to a string collection
            $viewFields = New-Object System.Collections.Specialized.StringCollection
            $viewFields.Add("Type") > $null
            $viewFields.Add("LinkFilename") > $null
            $viewFields.Add("Title") > $null
            $viewFields.Add("Modified") > $null
            $viewFields.Add("Modified By") > $null
            $viewFields.Add("Topic") > $null
            $viewFields.Add("Subtopic") > $null

            #Query property
            $viewQuery = "<GroupBy Collapse='TRUE' GroupLimit='100'> <FieldRef Name='ENetSubtopic' Ascending='FALSE'/> </GroupBy> <OrderBy> <FieldRef Name='Modified' Ascending='FALSE' /> </OrderBy>"
            #RowLimit property
            $viewRowLimit = 100
            #Paged property
            $viewPaged = $true
            #DefaultView property
            $viewDefaultView = $true

            #Create the view in the destination list
            $newview = $spContainer.Views.Add($viewTitle, $viewFields, $viewQuery, $viewRowLimit, $viewPaged, $viewDefaultView)

            Write-Host -f Green "View modifications completed"
        }
    }
    Stop-SPAssignment -Global  
}

Function Set-DefaultColumnValue([string]$column, [string]$columnVal)
{
	$columnDefaults.SetFieldDefault($spContainer.RootFolder, $column, $columnVal)
	$columnDefaults.Update()
}

Function Add-ViewColumns([string]$column, [int]$order)
{
	# Add column to view if it doesn't exist yet.
	if(!$view.ViewFields.ToStringCollection().Contains($column))
	{		
		$view.ViewFields.add($column)
		$view.Update()
	}
	# Set the column order if provided.
	if($order)
	{ 
		$view.ViewFields.MoveFieldTo($column,$order) 
		$view.Update()
	}
}

#***********************************************************************
#
# Create Subsite
#
#***********************************************************************
Function Create-Subsite([string]$webUrl, [string]$webTitle, [string]$spSiteTaxVal)
{

	$siteCheck = Get-SPWeb $webUrl -ErrorVariable err -ErrorAction SilentlyContinue -AssignmentCollection $assignmentCollection
    #$siteCheck = $False
    if($siteCheck)
    {
        Write-Host ("{0} already exists.  Skipping site creation." -f $webName)
        Write-Host $webUrl
    }
    else
    {
    
        New-SPWeb -url $webUrl -Name $webTitle -Template "CMSPUBLISHING#0"
    }

        #Get SP Site Collection
        $spSite = Get-SPSite $siteCollectionUrl

        # Get SP site/subsite
        $web=get-SPWeb $webUrl

        # Get SP Pages Library
        $list=$web.Lists["Pages"]

        # Get desired page
        $fileName = "default.aspx"

        # Set Page Content Type
        $spContentTypeName = "ENet Primary Page"
        $spPublishingCT = $spSite.RootWeb.ContentTypes[$spContentTypeName]
        $spPublishingCTId = [string]$spPublishingCT.Id
        $spContainer = $web.GetList($web.ServerRelativeUrl+"/Pages")

        # Check to see if content type exists already
        if ($spContainer.ContentTypes[$spContentTypeName] -eq $null)
            {

            # Add akn document content type in library
            $ct = $spContainer.ContentTypes.Add($spPublishingCT)
        }

        $item = $list.Items | ? {$_.Name -eq $fileName}
        $pubPage = [Microsoft.SharePoint.Publishing.PublishingPage]::GetPublishingPage($item)
        $pubPage.CheckOut()
        $pubPage.Title = $webTitle
        $pubPage.Update();

        $pageFile = $pubPage.ListItem.File;

        #Update Page Content Type
        $pageFile.Properties["ContentTypeId"] = $spPublishingCTId
        $pubPage.Update();
        $pageFile.Properties["PublishingPageLayout"] = $siteCollectionUrl + "/_catalogs/masterpage/ENet Site Primary.aspx, ENet Site Primary"
        $pageFile.Update();

        #Update Page Site property
        $pageFile.Properties["ENetSite"] = $spSiteTaxVal
        $pageFile.Update();
        $pageFile.CheckIn("Set page inital properties")
        $pageFile.Publish("");
        $web.Update()
        $web.Dispose()
    
}

#***********************************************************************
#
# Create Navigation
#
#***********************************************************************
Function Create-Navigation
{
	$web = Get-SPWeb $webUrl 
	$quickLaunch = $web.Navigation.QuickLaunch
	$clearNodes = $true
	$createLinks = $true

	if($clearNodes)
	{
		#------------------------------------------------------------------------------
		# QuickLaunch clean-up
		#------------------------------------------------------------------------------
		for($i = $web.Navigation.QuickLaunch.Count-1; $i -ge 0; $i--)
		{
		$web.Navigation.QuickLaunch[$i].Delete()
		}

	}

	#$quickLaunch = $web.Navigation.QuickLaunch

	if($createLinks)
	{
	#------------------------------------------------------------------------------
	# Home link [Special link]
	#------------------------------------------------------------------------------
	$navHome= New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Home", $webUrl , $false)
	$quickLaunch.AddAsFirst($navHome)

	#------------------------------------------------------------------------------
	# Site documents section [Header]
	#------------------------------------------------------------------------------
	$navSiteDocs = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Site Documents","javascript: return true;",$true)
	$quickLaunch.AddAsLast($navSiteDocs)

	#------------------------------------------------------------------------------
	# Site links section [Header]
	#------------------------------------------------------------------------------
	$navSiteLinks = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Site Links","javascript: return true;",$true)
	$quickLaunch.AddAsLast($navSiteLinks)

	#------------------------------------------------------------------------------
	# Page content section [Header]
	#------------------------------------------------------------------------------
	$navPageContent = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Page Content","javascript: return true;",$true)
	$quickLaunch.AddAsLast($navPageContent)

	#------------------------------------------------------------------------------
	# Document Hold library link [Special link]
	#------------------------------------------------------------------------------
	$navDocHoldUrl = $webUrl + "/Document Hold/Forms/AllItems.aspx"
	$navDocHold = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Document Hold", $navDocHoldUrl,$false)
	$quickLaunch.AddAsLast($navDocHold)

	#------------------------------------------------------------------------------
	# Archive library link [Special link]
	#------------------------------------------------------------------------------
	$navArchiveUrl = $webUrl + "/Archive Documents/Forms/AllItems.aspx"
	$navArchive = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Archives",$navArchiveUrl, $false)
	$quickLaunch.AddAsLast($navArchive)

	#------------------------------------------------------------------------------
	# Recycle bin link [Special link]
	#------------------------------------------------------------------------------
	$navRecycleBinUrl = $webUrl + "/_layouts/15/RecycleBin.aspx"
	$navRecycleBin = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Recycle Bin",$navRecycleBinUrl, $false)
	$quickLaunch.AddAsLast($navRecycleBin)
	}

	#------------------------------------------------------------------------------
	# Set structural navigation to global and current navigation
	#------------------------------------------------------------------------------

    #setting global and current navigation source
    $navSetting=new-object Microsoft.SharePoint.Publishing.Navigation.WebNavigationSettings($web)
    $navSetting.GlobalNavigation.Source=[Microsoft.SharePoint.Publishing.Navigation.StandardNavigationSource]::PortalProvider
    $navSetting.CurrentNavigation.Source=[Microsoft.SharePoint.Publishing.Navigation.StandardNavigationSource]::PortalProvider
    $navSetting.Update()

    #global navigation setting
    $SPPubWeb = [Microsoft.SharePoint.Publishing.PublishingWeb]::GetPublishingWeb($web)
    $SPPubWeb.Navigation.InheritGlobal = $false
    $SPPubWeb.Navigation.GlobalIncludeSubSites = $true
    $SPPubWeb.Navigation.GlobalIncludePages = $false
    $SPPubWeb.Navigation.GlobalDynamicChildLimit = 20

    #current navigation setting
    $SPPubWeb.Navigation.InheritCurrent = $false    
    $SPPubWeb.Navigation.ShowSiblings = $false
    $SPPubWeb.Navigation.CurrentIncludeSubSites = $true
    $SPPubWeb.Navigation.CurrentIncludePages = $true
    $SPPubWeb.Navigation.CurrentDynamicChildLimit = 20

    $SPPubWeb.Update()

}
cls
# Set new subsite full URL
$webUrl = $siteCollectionUrl + "/" + $webName

$spSiteTaxVal  = "-1;#" +$webTitle + "|" + $siteGUID

# Create new subsite
Create-Subsite $webUrl $webTitle $spSiteTaxVal

# Set Site Collection full URL
$spSite= Get-SPWeb $siteCollectionUrl

# Set Subsite full URL
$spWeb = Get-SPWeb $webUrl 

# Create Archive Documents
Create-DocLibrary "Archive Documents" "Document storage for content no longer in production and not visible to normal searchs." $null

# Create Hold Documents
Create-DocLibrary "Document Hold" "Temporary storage for content that belongs on the site, but the topic container is unknown." $null

# Create site navigation headers and special links
Create-Navigation

# Quick Launch Navigation Headers
$ql = $spWeb.Navigation.QuickLaunch
$siteDocumentsHeader = $ql | where {$_.title -eq "Site Documents"}
$siteLinksHeader = $ql | where {$_.title -eq "Site Links"}
$pageContentHeader = $ql | where {$_.title -eq "Page Content"}

# Get Termstore topics for site
$taxonomySession = Get-SPTaxonomySession -Site $spSite.Site
$termStore = $taxonomySession.TermStores["Managed Metadata Service"]
$group = $termstore.Groups | Where-Object { $_.Name -eq "Excellian.net"}
$termset = $group.TermSets["ExcellianSource"]
$guid = New-Object System.Guid($siteGUID)
$term = $termset.GetTerm($guid)

Foreach($t in $term.Terms)
{
    # Document library parameters
	$dlName = $t.Name + " Documents"
    if ($dlName.length -gt 50)
    {
        $dlName = $dlName.Substring(0,50)
    }

	$dlUrl = $webUrl + "/" + $dlName + "/Forms/AllItems.aspx"

	# Create document library by current topic
	Create-DocLibrary $dlName $t.Description $t.Id

	# Add a link to the quick launch navigation
	$navChildDocNode = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode($dlName, $dlUrl, $false)
	$siteDocumentsHeader.Children.AddAsLast($navChildDocNode)
	
	# Document library parameters
	$clName =  $t.Name + " Links"
	$clUrl = $webUrl + "/Lists/" + $clName + "/AllItems.aspx"

	# Create link library by current topic
	Create-LinkList $clName $t.Description $t.Id

	# Add a link to the quick launch navigation
	$navChildListNode = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode($clName, $clUrl, $false)
	$siteLinksHeader.Children.AddAsLast($navChildListNode)
}


# Create Related Links
Create-LinkList "Related Links" "A collection of list to related content on other sites." $null
$RelatedLinksUrl = $webUrl + "/Lists/" + "Related Links/AllItems.aspx"
$navChildListNode = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Related Links", $RelatedLinksUrl, $false)
$pageContentHeader.Children.AddAsLast($navChildListNode)

# Create Quick Links
Create-LinkList "Quick Links" "A collection of most commonly used links for the site." $null
$quickLinksUrl = $webUrl + "/Lists/" + "Quick Links/AllItems.aspx"
$navChildListNode = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Quick Links", $quickLinksUrl, $false)
$pageContentHeader.Children.AddAsLast($navChildListNode)
