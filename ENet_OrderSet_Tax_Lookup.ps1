﻿Add-PSSnapin "Microsoft.SharePoint.PowerShell"
clear

# File path and name
$ENetSourcefile = "E:\SPDocBatching\TermStore Termsets\ENet\OS_ENetSource_Termset.csv"
$ENetAudiencefile = "E:\SPDocBatching\TermStore Termsets\ENet\OS_Audience_Termset.csv"
$ENetDepartmentfile = "E:\SPDocBatching\TermStore Termsets\ENet\OS_Department_Termset.csv"
$ENetJsonFile = "E:\SPDocBatching\TermStore Termsets\ENet_Taxnomony.json"

# Create new files
New-Item $ENetSourcefile -type file -force
New-Item $ENetAudiencefile -type file -force
New-Item $ENetDepartmentfile -type file -force
New-Item $ENetJsonFile -type file -force

$url = "http://excellian.net"
$web = Get-SPWeb $url
$siteArray = @('')

$taxonomySession = Get-SPTaxonomySession -Site $web.Site
$termStore = $taxonomySession.TermStores["Managed Metadata Service"];
$termGroup = $termStore.Groups["Excellian.net"]


Function ENetSourceCVS
{
   Param ([string]$ENetSourceStr)

   Add-content $ENetSourcefile -value $ENetSourceStr
}
Function ENetAudienceCVS
{
   Param ([string]$ENetAudienceStr)

   Add-content $ENetAudiencefile -value $ENetAudienceStr
}

Function GetENetSourceTSValues
{
    $ENetSource = @()
    $termSet = $termGroup.TermSets["ExcellianSource"]

    # Search thru all terms
    foreach($t in $termSet.Terms)
    {

            #Write-Host "----------First Level: ----------------";
            $sourceVals1 = $t.Name + "|" + $t.Id + ";;"
            $ENetSource += $sourceVals1;

            #Write-Host "-----Second Level-----------------";

            foreach($t2 in $t.Terms)
            {
                $sourceVals2 = "" + $t.Name + "|" + $t.Id + ";" + $t2.Name + "|" + $t2.Id + ";"
                $ENetSource+= $sourceVals2

                #Write-Host "-----Third Level-----------------";

                foreach($t3 in $t2.Terms)
                {
                    $sourceVals3 = "" + $t.Name + "|" + $t.Id + ";" + $t2.Name + "|" + $t2.Id + ";" + $t3.Name + "|" + $t3.Id
                    $ENetSource+= $sourceVals3
                }
            }


    }
    Write-Host "ExcellianSource total items: " $ENetSource.Count
    Write-Host "--------------------------------------------------------------------"
    ENetSourceCVS "Site;Topic;Subtopic"

    foreach($s in $ENetSource)
    {
        ENetSourceCVS $s
        Write-Host $s;

    }
}
Function GetENetAudienceTSValues
{
    $ENetAudience = @()
    $termSet = $termGroup.TermSets["ExcellianAudience"]

    # Search thru all terms
    foreach($dt in $termSet.Terms)
    {

            #Write-Host "----------First Level: ----------------";
            $ENetAudienceVals1 = "" + $dt.Name + "|" + $dt.Id + ";" + $dt.Name + ";" + $dt.Id
            $ENetAudience += $ENetAudienceVals1;


    }
    Write-Host "Excellian Audience (Location) total items: " $ENetAudience.Count
    Write-Host "--------------------------------------------------------------------"
    ENetAudienceCVS "Location;Name;ID"

    foreach($s in $ENetAudience)
    {
        ENetAudienceCVS $s
        Write-Host $s;

    }
}

Function ENetDepartmentCVS
{
   Param ([string]$ENetDepartmentStr)

   Add-content $ENetDepartmentfile -value $ENetDepartmentStr
}

Function GetENetDepartmentTSValues
{
    $ENetDepartment = @()
    $termSet = $termGroup.TermSets["ExcellianDepartmentSpecialties"]

    # Search thru all terms
    foreach($dt in $termSet.Terms)
    {

            #Write-Host "----------First Level: ----------------";
            $ENetDepartmentVals1 = "" + $dt.Name + "|" + $dt.Id + ";" + $dt.Name + ";" + $dt.Id
            $ENetDepartment += $ENetDepartmentVals1;


    }
    Write-Host "Excellian Department total items: " $ENetDepartment.Count
    Write-Host "--------------------------------------------------------------------"
    ENetDepartmentCVS "Department;Name;ID"

    foreach($s in $ENetDepartment)
    {
        ENetDepartmentCVS $s
        Write-Host $s;

    }
} 
  
GetENetSourceTSValues
GetENetAudienceTSValues
GetENetDepartmentTSValues
GetENetApplicationTSValues
GetENetRoleTSValues