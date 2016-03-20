#!/bin/bash


#########################################
# Update LDAP conf
#########################################

function setLdapConf {
	KEY="$1"
	VALUE="$2"
	echo "Setting LDAP conf: $KEY=$VALUE"
	sed -i "s/^\s*$KEY\s*=.*$/$KEY=$VALUE/g" /etc/dovecot/dovecot-ldap.conf.ext
}

# Set LDAP conf: base (ex: base=dc=mail, dc=example, dc=org)
if [ -n "$LDAP_BASE" ]; then
	setLdapConf "base" "$LDAP_BASE"
fi

# Set LDAP conf: user_filter and pass_filter (ex: user_filter = (uid=%n))
if [ -n "$LDAP_USER_FIELD" ]; then
	setLdapConf "user_filter" "($LDAP_USER_FIELD=%n)"
	setLdapConf "pass_filter" "($LDAP_USER_FIELD=%n)"
fi

# Set LDAP conf: pass_attrs (ex: pass_attrs = uid=user,userPassword=password)
if [ -n "$LDAP_USER_FIELD" ]; then
	setLdapConf "pass_attrs" "$LDAP_USER_FIELD=user"
fi


#########################################
# Generate SSL certification
#########################################

CERT_FOLDER="/etc/ssl/localcerts"
KEY_PATH="$CERT_FOLDER/imap.key.pem"
CSR_PATH="$CERT_FOLDER/imap.csr.pem"
CERT_PATH="$CERT_FOLDER/imap.cert.pem"

if [ ! -f $CERT_PATH ] || [ ! -f $KEY_PATH ]; then
	mkdir -p $CERT_FOLDER

    echo "SSL Key or certificate not found. Generating self-signed certificates"
    openssl genrsa -out $KEY_PATH

    openssl req -new -key $KEY_PATH -out $CSR_PATH \
    -subj "/CN=imap"

    openssl x509 -req -days 3650 -in $CSR_PATH -signkey $KEY_PATH -out $CERT_PATH
fi


#########################################
# Start dovecot
#########################################

function stop_service {
	if [ -n $DOVECOT_PID ]; then
		echo ""
		echo "#########################################"
		echo "Stopping Dovecot"
		echo "#########################################"
		kill $DOVECOT_PID
	fi
}

function start_service {
	echo ""
	echo "#########################################"
	echo "Starting Dovecot"
	echo "#########################################"
	dovecot -F &
	DOVECOT_PID=$!
}

trap "stop_service; exit 0" SIGINT SIGTERM

start_service
wait $DOVECOT_PID