#!/bin/bash

#In Sophos Central generate an API Client ID and Client Secret.
#Supply the Client ID, Client Secret, and Tenant Name in Sophos to install.
#Example: ./Mac_Sophos_EndpointProtection_Install.sh -c ClientID -s ClientSecret -t "Tenant Name"

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit
fi

SophosAuthToken () {
    response=$(curl -s https://id.sophos.com/api/v2/oauth2/token \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=$1&client_secret=$2&scope=token")
    read -r -d '' JXA <<EOF
function run() {
    var response = JSON.parse(\`$response\`);
    return response.access_token
}
EOF

    token=$( osascript -l 'JavaScript' <<< "${JXA}" )
    echo "${token}"
}

SophosWhoAmI () {
    response=$(curl -s https://api.central.sophos.com/whoami/v1 \
        -X GET \
        -H "Authorization: Bearer $1")
    read -r -d '' JXA <<EOF
function run() {
    var response = JSON.parse(\`$response\`);
    var resp = response.idType + ":" + response.id;
    return resp;
}
EOF

    resp=$( osascript -l 'JavaScript' <<< "${JXA}" )
    idType=''
    id=''

    IFS=' : '
    read -ra ADDR <<< "$resp"
    for i in "${ADDR[@]}"; do
        if [ -z $idType ]
        then
            idType=$i
        else
            id=$i
        fi
    done
    IFS=' '

    echo $idType $id
}

SophosAuthHeaderId () {
    if [[ $1 = 'partner' ]]
    then
        echo "X-Partner-ID: $2"
    elif [[ $1 = 'organization' ]]
    then
        echo "X-Organization-ID: $2"
    elif [[ $1 = 'tenant' ]]
    then
        echo "X-Tenant-ID: $2"
    else
        echo ""
    fi
}

SophosTenantId () {
    p=1
    tenantId=0
    region=''
    until ! [ $tenantId == 0 ]
    do
        url="https://api.central.sophos.com/partner/v1/tenants?page=$p"
        response=$(curl -s $url -X GET -H "Authorization: Bearer $1" -H "$2")
        if [[ $response == *"error"* ]]; then
            break
        fi
        read -r -d '' JXA <<EOF
function run() {
    var response = JSON.parse(\`$response\`);
    for(var i = 0; i < response.items.length; i++) {
        if(response.items[i].name === '$3') {
            var combined = response.items[i].id + ':' + response.items[i].dataRegion;
            return combined;
        }
    }

    if(response.items.length === 0) {
        return 1;
    }

    return 0;
}
EOF
        tenantId=$( osascript -l 'JavaScript' <<< "${JXA}" )
        ((p++))
    done

    if [[ $tenantId == *":"* ]]; then
        IFS=' : '
        read -ra ADDR <<< "$tenantId"
        tenantId=''
        for i in "${ADDR[@]}"; do
            if [ -z $tenantId ]
            then
                tenantId=$i
            else
                region=$i
            fi
        done
        IFS=' '

        echo $tenantId $region
    else
        echo $tenantId ""
    fi
}

SophosInstallerUrl () {
    url="https://api-$3.central.sophos.com/endpoint/v1/downloads"
    response=$(curl -s $url -X GET -H "Authorization: Bearer $1" -H "X-Tenant-ID: $2")
    read -r -d '' JXA <<EOF
function run() {
    var response = JSON.parse(\`$response\`);
    if(response.installers.length === 0) {
        return 0;
    }

    for(var i = 0; i < response.installers.length; i++) {
        if(response.installers[i].platform === "macOS") {
            return response.installers[i].downloadUrl;
        }
    }

    return 1;
}
EOF
    downloadUrl=$( osascript -l 'JavaScript' <<< "${JXA}" )
    echo $downloadUrl
}

SophosUninstall() {
    if [ -d /Library/Application\ Support/Sophos/saas/Installer.app/Contents/MacOS/tools ]; then
        /Library/Application\ Support/Sophos/saas/Installer.app/Contents/MacOS/tools/InstallationDeployer --remove
    else
        echo "Installer missing. Exiting..."
        exit 1
    fi
}

while getopts :c:s:t:u flag
do
    case "${flag}" in
        c) clientId=${OPTARG};;
        s) clientSecret=${OPTARG};;
        t) tenantName=${OPTARG};;
        u) uninstall="true";;
    esac
done

#Fixes for extra single quotes from rmm
clientId=$( echo $clientId | sed -e "s/'//g" )
clientSecret=$( echo $clientSecret | sed -e "s/'//g" )
tenantName=$( echo $tenantName | sed -e "s/'//g" )

if ! [ -z $uninstall ]
then
    echo "Uninstalling Sophos..."
    SophosUninstall
    exit 0
fi

if [ -z "$clientId" ] || [ -z "$clientSecret" ] || [ -z "$tenantName" ]
then
    echo "Usage: ./Mac_Sophos_EndpointProtection_Install.sh -c ApiClientID -s ApiClientSecret -t \"TenantName\""
else
    echo "Checking if Sophos is already installed..."
    if ls /Applications | grep -i Sophos > /dev/null 2>&1; then
        echo "Sophos is already installed."
        exit 0
    fi

    echo "Obtaining auth token from Sophos."
    token="$(SophosAuthToken $clientId $clientSecret)"
    if [ -z "$token" ]
    then
        echo "Auth token was empty, check your API credentials."
        exit 1
    fi

    echo "Checking API credential level."
    read type id < <(SophosWhoAmI $token)

    authHeader=$(SophosAuthHeaderId $type $id)
    echo "Searching for Tenant ID."
    read tenantId region < <(SophosTenantId "$token" "$authHeader" "$tenantName")
    if [ $tenantId == 0 ]; then
        echo "There was an error communicating with the API."
        exit 1
    fi
    
    if [ $tenantId == 1 ]
    then
        echo "Could not find Tenant with name $tenantName"
        exit 1
    fi

    echo "Getting Sophos download URL."
    url=$(SophosInstallerUrl $token $tenantId $region)
    if [ $url = 0 ]; then
        echo "Found no installers."
        exit 1
    fi

    if [ $url = 1 ]; then
        echo "Error getting installer URL."
    fi

    echo "Downloading Sophos installer..."
    curl -s $url -o /tmp/SophosMacInstall.zip
    echo "Deflating Sophos installer..."
    [ -d "/tmp/SophosMacInstall" ] && rm -rf /tmp/SophosMacInstall
    unzip -q /tmp/SophosMacInstall.zip -d /tmp/SophosMacInstall
    echo "Installing Sophos..."
    /tmp/SophosMacInstall/Sophos\ Installer.app/Contents/MacOS/Sophos\ Installer --quiet
    echo "Cleaning up."
    rm -rf /tmp/SophosMacInstall
    echo "The user will be prompted to allow Sophos in Security Preferences. Follow those prompts."
fi