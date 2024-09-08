# LDAP User Search and SSH Key Retrieval Script

This script is designed to query a remote LDAP server for a user's group memberships and retrieve the SSH public key if it is stored in LDAP. It dynamically searches for the correct organizational unit (OU) and user groups based on the server's hostname. The script can be integrated with SSH’s `AuthorizedKeysCommand` to automatically retrieve SSH keys from LDAP during user login.

<u><strong>It allow permissions fine tuning- you can allow access to one server or group of servers</strong></u>

## Features

- **Dynamic Group Search**: Automatically searches LDAP groups based on the server's hostname.
- **SSH Key Retrieval**: Retrieves the SSH public key from LDAP if the user is found in the groups.
- **LDAP Integration**: Connects to a remote LDAP server using admin credentials.
- **SSH Integration**: Can be used as the `AuthorizedKeysCommand` to fetch keys from LDAP during SSH login.
- **LDAP Schema Import**: Includes an LDIF file for adding `ldapPublicKey` and `sshPublicKey` attributes to store SSH keys in LDAP.

## Prerequisites

1. **LDAP Utilities**: The `ldapsearch` command-line tool must be installed.
   - **Debian/Ubuntu**:
     ```bash
     sudo apt-get install ldap-utils
     ```
   - **CentOS/RHEL**:
     ```bash
     sudo yum install openldap-clients
     ```

2. **LDAP Access**: You must have LDAP admin credentials and access to the LDAP server.

3. **SSH Key Schema**: To store SSH keys in LDAP, you must import the `ssh-ldap-key.ldif` file, which defines `ldapPublicKey` and `sshPublicKey` attributes.
4. In the LDAP you need few groups to get it work - the main is  "ou=sshgroups,dc=example,dc=com". Then you need two subfolders "ou=servergroups,ou=sshgroups,dc=example,dc=com" and "ou=accessgroups,ou=sshgroups,dc=example,dc=com" (jubox is hostname of example server)

    ![LDAP Groups](/screenshots/LDAP.png?raw=true)


## Script Setup

### Step 1: Import LDAP Schema

Before using the script, you need to import the `ssh-ldap-key.ldif` file to add support for SSH keys in your LDAP directory.

1. Create a file called `ssh-ldap-key.ldif` with the following content (or download it from repo):

    ```
    dn: cn=lpk-openssh,cn=schema,cn=config
    objectClass: olcSchemaConfig
    cn: lpk-openssh
    olcAttributeTypes: {0}( 1.3.6.1.4.1.24552.500.1.1.1.13 NAME 'sshPublicKey' DES
     C 'MANDATORY: OpenSSH Public key' EQUALITY octetStringMatch SYNTAX 1.3.6.1.4.
     1.1466.115.121.1.40 )
    olcObjectClasses: {0}( 1.3.6.1.4.1.24552.500.1.1.2.0 NAME 'ldapPublicKey' DESC
      'MANDATORY: OpenSSH LPK objectclass' SUP top AUXILIARY MAY ( sshPublicKey $ 
     uid ) )
    ```

2. Import this schema into your LDAP server using the `ldapadd` command:

    ```bash
    ldapadd -Y EXTERNAL -H ldapi:/// -f ssh-ldap-key.ldif
    ```

This command adds the ability to store `sshPublicKey` attributes for LDAP users.

### Step 2: Update and Configure the Script

1. Download or clone this repository to the server where you plan to run the script - e.g. "/usr/local/bin/"

2. Open the script and update the LDAP connection settings:

   ```bash
   LDAP_SERVER="ldap://example.com:389"
   LDAP_USER="cn=admin,dc=rootdirectory"
   LDAP_PASS="admin_password"
   ```

3. Replace LDAP_SERVER with your LDAP server's URL, and provide the correct LDAP_USER (admin DN) and LDAP_PASS.

4. Make the script executable: 
    ```bash
    chmod +x /usr/local/bin/ldap-ssh-keys.sh
    ```

### Step 3: Modify SSH Configuration
To enable automatic SSH key retrieval from LDAP during user login, you need to modify the SSH server configuration.

1. Open /etc/ssh/sshd_config and add the following lines:

    ```bash
    AuthorizedKeysCommand /usr/local/bin/ldap-ssh-keys.sh %u
    AuthorizedKeysCommandUser nobody
    ```

    AuthorizedKeysCommand: Specifies the script to run for retrieving SSH keys.
    AuthorizedKeysCommandUser: Defines the user under which the script will run (nobody is a safe, restricted user).

2. Restart the SSH service for the changes to take effect:
    ```bash
    sudo systemctl restart sshd
    ```

### Step 4: Usage
You can manually run the script by passing a username as an argument to list key of user:
```bash
/usr/local/bin/ldap-ssh-keys.sh <username>
```


### Step 5: What the Script Does
- Search for Groups: The script queries the LDAP server to find groups under ou=servergroups,ou=sshgroups,dc=rootdirectory where the group's common name (CN) is based on the server's hostname (e.g., hostname-ssh).

- Dynamic Organizational Unit Search: If the user is not found in the primary group, the script searches other organizational units (OUs), such as webservers, routers, etc., under ou=accessgroups.

- SSH Key Retrieval: If the user is found in a group, the script retrieves their SSH public key from the cn=<username>,ou=users subtree, specifically from the sshPublicKey attribute.

- Fallback Mechanism: If the user is not found in the initial group, the script dynamically searches for other related groups to locate the user.

## Example
If you need access to jubox sever, you have to be member of cn=jubox,ou=webservers,ou=servergroups,ou=sshgroups,dc=example,dc=com or "cn=webservers,ou=accessgroups,ou=sshgroups,dc=example,dc=com"

    ![LDAP Groups](/screenshots/LDAP.png?raw=true)

## Troubleshooting
### Common Issues
+ Authentication Errors: Ensure the correct LDAP admin credentials (DN and password) are configured in the script.
+ Connection Issues: Verify that the LDAP server address and port (default: 389) are correct and that the server is reachable.
+ User Not Found: Ensure the correct username is being passed and that the user exists in the correct LDAP groups.
+ SSH Key Retrieval: Ensure that the sshPublicKey attribute is properly set for the user in LDAP. The SSH key must be in the correct format (e.g., ssh-rsa <key>).