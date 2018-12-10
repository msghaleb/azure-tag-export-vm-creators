$createdByLabel = "CreatedBy";
$eventsstarttime = (Get-Date).AddDays(-89);

# Login Function (needed only locally)
Function Login
{
    $needLogin = $true

    # checking the AzureRM connection if login is needed
    Try 
    {
        $content = Get-AzureRmContext
        if ($content) 
        {
            $needLogin = ([string]::IsNullOrEmpty($content.Account))
        } 
    } 
    Catch 
    {
        if ($_ -like "*Login-AzureRmAccount to login*") 
        {   
            $needLogin = $true
        } 
        else 
        {
            Write-Host "You are already logged in to Azure, that's good."
            throw
        }
    }

    if ($needLogin)
    {
        Write-Host "You need to login to Azure"
        Login-AzureRmAccount
    }

    # Checking the Azure AD connection and if login is needed
    #try { 
    #    Get-AzureADTenantDetail 
    #}
    #catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
    #    Write-Host "You're not connected to the Azure AD."
    #    Connect-AzureAD
    #}

}

#checking if you are on Azure Shell
if ( (Get-Module | where-Object {$_.Name -like "AzureAD.Standard.Preview"}).Count ) {
    Write-Host "You are on Azure Shell"
}
else {
    Write-Host "You are working locally"
    # checking if you have the needed modules installed
    # check for and install the AzureAD if needed
    Import-Module AzureAD -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object {$_.Name -like "AzureAD"}).Count ) { Install-Module AzureAD -scope CurrentUser }

    # check for and install the AzureRM if needed
    Import-Module AzureRm.Resources -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object {$_.Name -like "AzureRM.Resources"}).Count ) { Install-Module AzureRM -scope CurrentUser}

    # Loggin in to Azure (if needed)
    Login
}

function setTag 
{ 
    param ([string]$caller, $vM) 
    $newTags = $vM.Tags + @{ $createdByLabel = $caller }; 
    Set-AzureRmResource -Tag $newTags -ResourceId $vM.Id -Force | Out-Null; 
}

#Setting the current date and time for folder creating
$currentDate = $((Get-Date).ToString('yyyy-MM-dd--hh-mm'))

#creating a sub folder for the output.
Write-Host "Creating a Sub Folder for the output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate"  | Out-Null
    # setting the path
    $outputPath = ".\$currentDate"
} 
Catch {
    Write-Output "Failed to create the output folder, please check your permissions"
}

#creating a sub folder for the subscriptions one by one.
Write-Host "Creating a Sub Folder for the subscriptions one by one output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate\subscriptions_one_by_one"  | Out-Null
    # setting the path
    $subsPath = ".\$currentDate\subscriptions_one_by_one"
} 
Catch {
    Write-Output "Failed to create the subscriptions sub folder, please check your permissions"
}

# Export VMs for all subscriptions the user has access to

    $AzureVMs = @()
    $AzureVMs2 = @()
    #Loop through each Azure subscription user has access to
    Foreach ($sub in Get-AzureRmSubscription) {
        $SubName = $sub.Name
        if ($sub.Name -ne "Access to Azure Active Directory") { # There is no VMs in Access to Azure Active Directory subscriptions
            Set-AzureRmContext -SubscriptionId $sub.id | Out-Null
            Write-Host "Collecting the VMs info for $subname"
            Write-Host ""
            Try {
                #############################################################################################################################
                #### Modify this line to filter what you want in your results
                #############################################################################################################################
                $Current = Get-AzureRmVm | Select-Object -Property @{Name = 'SubscriptionName'; Expression = {$sub.name}}, @{Name = 'SubscriptionID'; Expression = {$sub.id}}, Name, @{Label="Creator";Expression={$_.Tags["CreatedBy"]}}, @{Label="VmSize";Expression={$_.HardwareProfile.VmSize}}, @{Label="OsType";Expression={$_.StorageProfile.OsDisk.OsType}}, Location, VmId, ResourceGroupName, Id
                $AzureVMs += $Current
            } 
            Catch {
                Write-Output "Failed to collect the VMs for $subname"
            }
            
            #Now we need the person who created the VM
            Foreach ($AzureVM in $Current) {
              #If the VM is not Taged with CreatedBy, we will set it.
              if (!$AzureVM.Creator) {
                write-host " No CreatedBy Tag found for the VM : " $AzureVM.Name -ForegroundColor Red
                $events = Get-AzureRmLog -ResourceId $AzureVM.Id -StartTime $eventsstarttime -WarningAction SilentlyContinue | Sort-Object -Property EventTimestamp;
                if ($events.Count -gt 0) 
                {
                    Write-Host " I've found some Activity log events for the VM : " $AzureVM.Name -ForegroundColor Yellow
                    $location = 0; 
                    $entityOnly = $true; 
                    foreach($event in $events) 
                    { 
                        if($event[$location].Caller -like "*@*") 
                        {
                            Write-Host " you have good luck, a creator is found in the logs "  $events[$location].Caller -ForegroundColor Green
                            setTag -caller $events[$location].Caller -vM $AzureVM;
                            Write-Host " I've set the owner of the VM : " $AzureVM.Name " to " $events[$location].Caller -ForegroundColor Blue -BackgroundColor Yellow
                            $entityOnly = $false; 
                            break
                        } 
                    }
                    if ($entityOnly -eq $true) 
                    { 
                    Write-Host " Human creator not available, going with entity..." -ForegroundColor Yellow
                    setTag -caller $events[0].Caller -vM $AzureVM; 
                    } 
                }
                else {
                    Write-Host " No creator information available..." -ForegroundColor Red
                    setTag -caller "Creator is Unknown" -vM $AzureVM; 
                }
              } 
              else 
              {
                Write-Host "Creator Tag was found : " $AzureVM.Creator -ForegroundColor Blue -BackgroundColor Black 
              }  
            }
        #Export the VMs to a CSV file labeled by the subscription name
        $Current2 = Get-AzureRmVm | Select-Object -Property @{Name = 'SubscriptionName'; Expression = {$sub.name}}, @{Name = 'SubscriptionID'; Expression = {$sub.id}}, Name, @{Label="Creator";Expression={$_.Tags["CreatedBy"]}}, @{Label="VmSize";Expression={$_.HardwareProfile.VmSize}}, @{Label="OsType";Expression={$_.StorageProfile.OsDisk.OsType}}, Location, VmId, ResourceGroupName, Id
        $AzureVMs2 += $Current2
        $csvSubName = $SubName.replace("/","---")
        $Current2 | Export-CSV "$subsPath\Subscription--$csvSubName-VMs.csv" -Delimiter ';'
        }
    }

    #Export All VMs in to a single CSV file
    $AzureVMs2 | Export-CSV "$outputPath\Azure--All-VMs.csv" -Delimiter ';'

    # HTML report
    $a = "<style>"
    $a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-family:arial}"
    $a = $a + "TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
    $a = $a + "TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
    $a = $a + "</style>"
    $AzureVMs2 | ConvertTo-Html -Head $a| Out-file "$outputPath\AzureAllVms.html"