#!/bin/bash
set -e

# check if the user is root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi


#
# Check left over mdm profiles
#
echo "Checking for left over mdm profiles ..."
echo "..."
has_user_profiles=$(profiles list | grep -v "There are no" | wc -l | awk '{print $1}')
has_system_profiles=$(sudo profiles list | grep -v "There are no" | wc -l | awk '{print $1}')
# tell user to remove all profiles if they exist
if [ $has_user_profiles -gt 0 ] || [ $has_system_profiles -gt 0 ]; then
    echo "Please manually remove all leftover mdm profiles"
    echo "under Settings > General > Device Management"
    echo "open Settings menu (y/n)?"
    read -n 1 -s answer
    if [ "$answer" = "y" ]; then
        open "x-apple.systempreferences:com.apple.preferences.configurationprofiles"
    fi
fi
echo ""

#
# Force unbind from active directory if bound
# 
echo ""
echo "Checking for active directory binding ..."
echo "..."
is_bound=$(dsconfigad -show | grep "Active Directory Domain" | wc -l)
if [ $is_bound -gt 0 ]; then
    echo "Unbinding from active directory! accept (y/n)?"
    read -n 1 -s answer
    if [ "$answer" = "y" ]; then
        dsconfigad -force -remove -u johndoe -p nopasswordhere
    fi
fi
echo ""
#
# Delete keypairs
#
echo ""
echo "Checking for leftover keypairs (cert/private key pairs)..."
echo "..."
keypairs=$(/usr/bin/security find-identity -v \
                    | grep office.root.local \
                    | awk '{print $3" "$2}' \
                    | tr -d '"' )

keypairs="$(echo "$keypairs" | paste -d " "  -)"

if [ -n "$keypairs" ]; then
    echo "please manually delete the following keypairs in the keychain access app:"
    echo ""
    echo "certificates | fingerprint" 
    echo "$keypairs"
fi
echo ""

#
# Delete certificates
#
echo ""
echo "Checking for certificates..."
echo "..."
all_certs=$(/usr/bin/security find-certificate -a -p)
certs_todelete=()
certstr=""
# read per line
while IFS= read -r line; do
    certstr+="$line"$'\n'
    if [ "$line" = "-----END CERTIFICATE-----" ]; then
        if [ $(echo "$certstr" | openssl x509 -noout -subject | grep -E "office.root.local|GruppenCA" | wc -l) -gt 0 ]; then
          formated_cert=$(echo "$certstr" \
          | openssl x509 -noout -subject -fingerprint \
          | awk '{print $1" "$2}' \
          | tr -d ':' \
          | sed 's/DC=local\/DC=root\/CN=//' \
          | sed 's/subject= \/CN=//' \
          | sed 's/Fingerprint=//' \
          | tr -d '\n')
          certs_todelete+=("$formated_cert")
        fi

        certstr=""
    fi

done <<< "$all_certs"

if [ ${#certs_todelete[@]} -gt 0 ]; then
    echo "please manually delete the following certificates in the keychain access app"
    echo "certificates | fingerprint" 
    echo ""
    for cert in "${certs_todelete[@]}"; do
        echo $cert
    done
fi
echo ""
