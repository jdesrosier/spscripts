Clear
$web = Get-SPWeb "http://spsdev01/sprintdev/site1b"

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

$quickLaunch = $web.Navigation.QuickLaunch

if($createLinks)
{
#------------------------------------------------------------------------------
# Home link
#------------------------------------------------------------------------------
$navNode1 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Home", "http://spsdev01/sprintdev/site1b/Pages", $false)
$quickLaunch.AddAsFirst($navNode1)

#------------------------------------------------------------------------------
# Document library section
#------------------------------------------------------------------------------
$navNode2 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Site Documents","javascript: return true;",$true)
$quickLaunch.AddAsLast($navNode2)

#------------------------------------------------------------------------------
# Link list section
#------------------------------------------------------------------------------
$navNode3 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Site Links","javascript: return true;",$true)
$quickLaunch.AddAsLast($navNode3)

#------------------------------------------------------------------------------
# Misc document library link
#------------------------------------------------------------------------------
$navNode4 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Misc Docs","http://spsdev01/sprintdev/site1b/Misc/Forms/AllItems.aspx",$false)
$quickLaunch.AddAsLast($navNode4)

#------------------------------------------------------------------------------
# Archive library link
#------------------------------------------------------------------------------
$navNode5 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Archives","http://spsdev01/sprintdev/site1b/Archives/Forms/AllItems.aspx", $false)
$quickLaunch.AddAsLast($navNode5)

#------------------------------------------------------------------------------
# Recycle bin link
#------------------------------------------------------------------------------
$navNode6 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Recycle Bin","http://spsdev01/sprintdev/site1b/_layouts/15/RecycleBin.aspx", $false)
$quickLaunch.AddAsLast($navNode6)

$web2 = Get-SPWeb "http://spsdev01/sprintdev/site1b"
$ql = $web2.Navigation.QuickLaunch
#$ql | Select Title
#------------------------------------------------------------------------------
# Site documents children links
#------------------------------------------------------------------------------
$heading1 = $ql | where {$_.title -eq "Site Documents"}

$navChildNode1 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("ITIL", "http://spsdev01/sprintdev/site1b/ITIL/Forms/AllItems.aspx", $false)
$heading1.Children.AddAsLast($navChildNode1)

$navChildNode2 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Google Search", "http://www.google.com", $true)
$heading1.Children.AddAsLast($navChildNode2)

#------------------------------------------------------------------------------
# Site Links childrn links
#------------------------------------------------------------------------------
$heading2 = $ql | where {$_.title -eq "Site Links"}

$navChildNode1 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Quick Links","http://spsdev01/sprintdev/site1b/Lists/QuickLinks/AllItems.aspx", $false)
$heading2.Children.AddAsLast($navChildNode1)

$navChildNode2 = New-Object Microsoft.SharePoint.Navigation.SPNavigationNode("Related Links","http://spsdev01/sprintdev/site1b/Lists/RelatedLinks/AllItems.aspx", $false)
$heading2.Children.AddAsLast($navChildNode2)


}

