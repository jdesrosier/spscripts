Param(

		#Example: ./AddTermSetData -webApp "AKN" -termSetName "AKNSource" -csvFile "E:\NewTerms.csv" [-displayWarnings True]

		# Web Application
		[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
		[string]$webApp,

		# TermSet Name
		[Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
		[string]$termSetName,

		# CSV File
		[Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$true)]
		[string]$csvFile,

        # Display Warnings
		[Parameter(Mandatory=$false, Position=3, ValueFromPipeline=$true)]
		[string]$displayWarnings

	)

Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue

clear

Function Add-TermValues
{

    # Set global variables.
    if($displayWarnings -eq $null)
    {
        $displayWarnings = $false
    }

    if ($webApp.Equals("AKN"))
    {
        $siteName = "http://akntest.allina.com"
        $termStoreName = "Managed Metadata Service"
        $GroupName = "Site Collection"
    }
    if($webApp.Equals("ENet"))
    {
        $siteName = "http://test.excellian.net"
        $termStoreName = "Managed Metadata Service"
        $GroupName = "Excellian.net"
    }

    # Connect to the TermStore.
    $taxSite = get-SPSite $siteName
    $taxonomySession = Get-SPTaxonomySession -site $taxSite
    $termStore = $taxonomySession.TermStores[$termStoreName]
    $termStoreGroup = $termStore.Groups[$GroupName]

    # Check TermSet status.
    $termSet = $termStoreGroup.TermSets[$termSetName]

    if($termSet -eq $null)
    {
        # TermSet not found. Create a new TermSet.
        $termSet = $termStoreGroup.CreateTermSet($termSetName)
        $termStore.CommitAll()

        Write-Host "TermSet:" $termSetName "created" -ForegroundColor yellow
    }
    else
    {
        # TermSet found. Use this TermSet.
        $termSet = $termStoreGroup.TermSets[$termSetName]

        write-host "Using termset:" $termSetName -ForegroundColor green
    }

    # Read CVS file to get new terms.
    Write-Host "Loading new values from CVS"
    $Terms = Import-CSV $csvFile

    Write-Host "Adding new values to" $termSetName "termset..."

    # Start level one: site value.
    Foreach ($term in $Terms)
    {
        # Check if site term value exists.
        if($term.L1T)
        {
            $termL1T = $termSet.Terms[$term.L1T]
            if($termL1T -eq $null)
            {
                # Term does not exist. Add new term.
                $termL1T = $termSet.CreateTerm($term.L1T, 1033)
                #$termL1T.SetDescription(“This is a test”, 1033)
                #$termL1T.CreateLabel(“This is a test synonym”, 1033, $false)
                $termStore.CommitAll()

                write-host "Site:" $term.L1T "was added"
            }
            else
            {
                # Term found. Do not add.
                if($displayWarnings)
                {
                    Write-Host "Site:" $term.L1T "already exists." -ForegroundColor yellow
                }
            }

            # Start level two: topic value.
            if($term.L2T)
            {
                $termL2T = $termL1T.Terms[$term.L2T]

                if ($termL2T -eq $null)
                {
                    # Term does not exist. Add new term.
                    $termL2T = $termL1T.CreateTerm(($term.L2T), 1033)
                    #$termL2T.SetDescription(“This is a test”, 1033)
                    #$termL2T.CreateLabel(“This is a test synonym”, 1033, $false)
                    $termStore.CommitAll()

                    write-host "Topic" $term.L2T "was added" -ForegroundColor cyan
                }
                else
                {
                    # Term found. Do not add.
                    if($displayWarnings)
                    {
                        Write-Host "Topic:" $term.L2T "already exists." -ForegroundColor yellow
                    }
                }

                # Start level three: subtopic value.
                if($term.L3T)
                {
                    # Check if site term values exists.
                    $termL3T = $termL2T.Terms[$term.L3T]

                    if($termL3T -eq $null)
                    {
                        # Not found. Add new term.
                        $termL3T = $termL2T.CreateTerm($term.L3T, 1033)
                        #$termL3T.SetDescription(“This is a test”, 1033)
                        #$termL3T.CreateLabel(“This is a test synonym”, 1033, $false)
                        $termStore.CommitAll()

                        Write-Host "Subtopic:" $term.L3T "added" -ForegroundColor cyan
                    }
                    else
                    {
                        # Term found. Do not add.
                        if($displayWarnings)
                        {
                            Write-Host "Subtopic:" $term.L3T "already exists." -ForegroundColor yellow
                        }
                    }
                }
            }
        }
    
    } 

    Write-Host "Finished loading new terms" -ForegroundColor green

}

Add-TermValues