# SetAppInstallMethod

This script is intended for Cloud Hosted Jamf Pro customers to change the install method of their Mac App Store or Mobile Device apps in bulk. This has to be done via the API when Cloud hosted since we don't have direct access to the database. 

For on-prem customers this could be more easily accomplished (and not to mention quicker) via the database and a couple MySQL commands. 

## Process to run script
1. Copy script to a location on a macOS or Linux device that has access to the internet
1. Run script with "bash /path/to/SetAppInstallMethod.sh"
    1. Use Terminal if on macOS.
1. Fill in data as prompted.



### ---Update 2019-06-19---
### Please note that due to PI-007146, the Mac App Store functionality is disabled in the script

PI-007146 relates to PUT commands not being processed correctly by the /macapplications API end point. Once that is resolved, I'll update the script to include the option again. 
