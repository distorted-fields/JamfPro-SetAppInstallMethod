#!/bin/bash
#
#
#     Created by A.Hodgson
#      Date: 06/19/2019
#      Purpose: Change the install method of a VPP application
#  
#
######################################

##############################################################
#
# Templates to parse the XML responses
#
##############################################################

cat << EOF > /tmp/mac_app_id.xslt
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/">
		<xsl:for-each select="mac_applications/mac_application">
			<xsl:value-of select="id"/>
			<xsl:text>,</xsl:text>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>
EOF


cat << EOF > /tmp/mda_id.xslt
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/">
		<xsl:for-each select="mobile_device_applications/mobile_device_application">
			<xsl:value-of select="id"/>
			<xsl:text>,</xsl:text>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>
EOF


##############################################################
#
# App Options
#
##############################################################

#Mac App Store Apps 
function macApps() 
{
	#get all apps from the API if necessary
	if [ "$app_target" == "1" ] ; then 
		#get apps
		macOS_apps=$(curl -sku "Accept: text/xml" -u "$apiUser":"$apiPass" "$jssURL/JSSResource/macapplications")
		#parse the API response and output the desired values based on the template above
		ids_CSV=$( echo "$macOS_apps" | xsltproc /tmp/mac_app_id.xslt - )
	fi
	
	echo ""
	idProcessor
}

#Mobile Device Apps 
function mdaApps() 
{
	#get all apps from the API if necessary 
	if [ "$app_target" == "1" ] ; then 
		iOS_apps=$(curl -sku "Accept: text/xml" -u "$apiUser":"$apiPass" "$jssURL/JSSResource/mobiledeviceapplications")
		#parse the API response and output the desired values based on the template above
		ids_CSV=$( echo "$iOS_apps" | xsltproc /tmp/mda_id.xslt - )
	fi

	echo ""
	idProcessor
}

##############################################################
#
# Processor Functions
#
##############################################################

#Process ID values
function idProcessor() 
{
	#read ID csv into array - the CSV is formatted differently if coming from the API so we need the two options below
	#coming from API
	if [ "$app_target" == "1" ] ; then 
		IFS=', ' read -r -a app_ids <<< "$ids_CSV"
	#provided by end user
	else
		IFS=$'\n' read -d '' -r -a app_ids < $ids_CSV
	fi

	#get a length for traversing
	length=${#app_ids[@]}

	#traverse app ids and pick appropriate curl command based on options set
	for ((i=0; i<$length;i++));
	do
		#trim the fat
		id=$(echo ${app_ids[i]} | sed 's/,//g' | sed 's/ //g'| tr -d '\r\n')

		#provide progress to terminal
		echo "Processing app id: $id"

		#macOS install auto
		if [[ ( "$install_option" == "1" ) && ( "$app_option" == "1" ) ]] ; then
			response=$(curl --write-out "%{http_code}" -sku "$apiUser":"$apiPass" -H "Content-Type: text/xml" "$jssURL/JSSResource/macapplications/id/$id" -X PUT -d "<mac_application><general><deployment_type>Install Automatically/Prompt Users to Install</deployment_type></general></mac_application>")
			responseStatus=${response: -3}
			apiResponse "$responseStatus"
		#iOS install audo
		elif [[ ( "$install_option" == "1" ) && ( "$app_option" == "2" ) ]] ; then
			response=$(curl --write-out "%{http_code}" -sku "$apiUser":"$apiPass" -H "Content-Type: text/xml" "$jssURL/JSSResource/mobiledeviceapplications/id/$id" -X PUT -d "<mobile_device_application><general><deployment_type>'Install Automatically/Prompt Users to Install'</deployment_type><deploy_automatically>true</deploy_automatically></general></mobile_device_application>")
			responseStatus=${response: -3}
			apiResponse "$responseStatus"
		#macOS install SS
		elif [[ ( "$install_option" == "2" ) && ( "$app_option" == "1" ) ]] ; then
			response=$(curl --write-out "%{http_code}" -sku "$apiUser":"$apiPass" -H "Content-Type: text/xml" "$jssURL/JSSResource/macapplications/id/$id" -X PUT -d "<mac_application><general><deployment_type>Make Available in Self Service</deployment_type></general></mac_application>")	
			responseStatus=${response: -3}
			apiResponse "$responseStatus"
		#iOS install SS
		elif [[ ( "$install_option" == "2" ) && ( "$app_option" == "2" ) ]] ; then	
			response=$(curl --write-out "%{http_code}" -sku "$apiUser":"$apiPass" -H "Content-Type: text/xml" "$jssURL/JSSResource/mobiledeviceapplications/id/$id" -X PUT -d "<mobile_device_application><general><deployment_type>'Make Available in Self Service'</deployment_type><deploy_automatically>false</deploy_automatically></general></mobile_device_application>")
			responseStatus=${response: -3}
			apiResponse "$responseStatus"
		else
			echo "Valid options not supplied. Exiting"
			exit 0
		fi
	done


	#provide final output based on app targeting
	echo ""
	if [ "$app_target" == "1" ] ; then
		echo "All apps have been set to install $ioption."
	else
		echo "The following app ids have been set to install $ioption:"
		for id in "${app_ids[@]}"
		do
			echo $id
		done
	fi
}

#provide output response of api calls
function apiResponse() #takes api response code variable
{
	if [ "$1" == "201" ] ; then
		echo "Success"
	else
		echo "Failed"
	fi
}

##############################################################
#
# Main Function
#
##############################################################

#prompt user for variables
read -p "Enter your Jamf Pro URL (eg. https://example.jamfcloud.com or https://onprem.jamfserver.com:8443): " jssURL
read -p "Enter a username used for authentication to the API: " apiUser
#user password hidden from terminal
prompt="Please enter your API user password: "
while IFS= read -p "$prompt" -r -s -n 1 char 
do
if [[ $char == $'\0' ]];     then
    break
fi
if [[ $char == $'\177' ]];  then
    prompt=$'\b \b'
    apiPass="${password%?}"
else
    prompt='*'
    apiPass+="$char"
fi
done
echo ""

#check the status of the API credentials before proceeding, exit script if fails
echo "Validating API credentials...."
apiCreds=$(curl --write-out %{http_code} --silent --output /dev/null -sku "Accept: text/xml" -u "$apiUser":"$apiPass" "$jssURL/JSSResource/mobiledeviceapplications")
if [ "$apiCreds" == "200" ]
then
	echo "Validated, proceeding."
else
	echo "Credentials or URL not valid, please try again. Exiting script...."
	exit 0
fi

#prompt user for App option and loop until we have a valid option 
while true; do
	echo ""
	echo "What types of apps would you like to set?"
	echo "1 - Mac App Store Apps - Currently Disabled due to PI-007146"
	echo "2 - Mobile Device Apps"
	read -p "Please enter an option number: " app_option

	case $app_option in 
		# uncomment these lines when PI-007146 is resolved
		# 1)
		# 	break
		# 	;;
		2)
			break
			;;
		*)
			echo "That is not a valid choice, try a number from the list."
     		;;
    esac
done

#prompt user for install option and loop until we have a valid option 
while true; do
	echo ""
	echo "Set the install method:"
	echo "1 - Automatic"
	echo "2 - Self Service"
	read -p "Please enter an option number: " install_option

	case $install_option in 
		1)
			ioption="automatically"
			break
			;;
		2)
			ioption="via Self Service"
			break
			;;
		*)
			echo "That is not a valid choice, try a number from the list."
     		;;
    esac
done

#prompt user for all apps or CSV option and loop until we have a valid option 
while true; do
	echo ""
	echo "What apps would you like to target?"
	echo "1 - All apps"
	echo "2 - Upload a CSV of app IDs"
	read -p "Please enter an option number: " app_target

	case $app_target in 
		1)
			echo ""
			echo "Targeting all apps"
			break
			;;
		2)
			echo ""
			read -p "Drag and drop your CSV of App IDs: " ids_CSV
			break
			;;
		*)
			echo "That is not a valid choice, try a number from the list."
     		;;
    esac
done

#call appropriate app function
if [ "$app_option" == "1" ] ; then
	macApps
else
	mdaApps
fi
