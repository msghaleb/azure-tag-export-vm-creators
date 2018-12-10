# Export all Azure VM Creators (not Owners) 
This Script will search for all Azure VM Creators in the Azure activity log then Tag all VMs with this Tag:

```
CreatedBy user@domain
```

After that it will export all VMs from all Subscriptions the user has access to in a CSV file.

Each Subscription will have a seperate CSV file 
> Subscription--{Subscription Name}.csv

There will also be a single CSV file with all RBAC permissions 
> Subscription--All-VMs.csv

The script should work locally and on Azure Shell

## Install required PowerShell modules if not already installed
### If on Windows 10+
   > Install the latest version of WMF 
   > https://www.microsoft.com/en-us/download/details.aspx?id=54616
   > Then run 'Install-Module PowerShellGet -Force'
### If on Windows previous to 10
   > Install PackageManagement modules
   > http://go.microsoft.com/fwlink/?LinkID=746217
   > Then run 'Install-Module PowerShellGet -Force'

### Feel free to open a pull request if you like to improve this script
