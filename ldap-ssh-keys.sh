#!/bin/bash

SERVERNAME=$(hostname)
USERNAME=$1


LDAP_SERVER="ldap://example.com:389"
LDAP_USER="cn=admin,dc=example,dc=com"
LDAP_PASS="admin_password"


RESULT=$(ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_USER" -LLL -w "$LDAP_PASS" -b "ou=servergroups,ou=sshgroups,dc=example,dc=com" "cn=${SERVERNAME}" memberUid)

DYNAMIC_OU=$(echo "$RESULT" | grep -o "ou=[^,]*" | head -n 1)
#echo $RESULT
#echo $DYNAMIC_OU

if echo "$RESULT" | grep -q "memberUid: ${USERNAME}"; then
        USER_SSH_KEY=$(ldapsearch -H "$LDAP_SERVER" -D "$LDAP_USER" -w "$LDAP_PASS" -LLL -b "uid=${USERNAME},ou=users,dc=example,dc=com" -o ldif-wrap=no  sshPublicKey| grep sshPublicKey: |cut -d" " -f 2-4 )

    if echo "$USER_SSH_KEY" | grep -q "ssh"; then
        echo "$USER_SSH_KEY" 
    else
        echo "No SSH key found for ${USERNAME}."| systemd-cat -p warning
    fi

else
    RESULT2=$(ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_USER" -w "$LDAP_PASS" -b "cn=$(echo "$DYNAMIC_OU" | cut -d '=' -f 2),ou=accessgroups,ou=sshgroups,dc=example,dc=com" memberUid | grep "memberUid: ${USERNAME}")
    
    if  echo "$RESULT2" | grep -q "memberUid: ${USERNAME}"; then
        
        USER_SSH_KEY=$(ldapsearch -H "$LDAP_SERVER" -D "$LDAP_USER" -w "$LDAP_PASS" -LLL -b "uid=${USERNAME},ou=users,dc=example,dc=com" -o ldif-wrap=no  sshPublicKey| grep sshPublicKey: |cut -d" " -f 2-4 )

          if echo "$USER_SSH_KEY" | grep -q "ssh"; then
            echo "$USER_SSH_KEY"
        else
            echo "No SSH key found for ${USERNAME}."| systemd-cat -p warning
        fi
    else
        echo "User ${USERNAME} not found in any group."| systemd-cat -p warning
    fi
fi
