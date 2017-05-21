#!/bin/bash


#########################################
# Update Dovecot conf
#########################################

function setDovecotConf {
	KEY="$1"
	VALUE="$2"
	FILE="$3"
	echo "Setting conf: $KEY=$VALUE in ($FILE)"
	sed -i "s#^\s*$KEY\s*=.*\$#$KEY=$VALUE#g" $FILE
}

# Set LDAP conf: base (ex: base=dc=mail, dc=example, dc=org)
if [ -n "$LDAP_BASE" ]; then
	setDovecotConf "base" "$LDAP_BASE" /etc/dovecot/dovecot-ldap.conf.ext
fi

# Set LDAP conf: user_filter and pass_filter (ex: user_filter = (uid=%n))
if [ -n "$LDAP_USER_FIELD" ]; then
	setDovecotConf "user_filter" "($LDAP_USER_FIELD=%n)" /etc/dovecot/dovecot-ldap.conf.ext
	setDovecotConf "pass_filter" "($LDAP_USER_FIELD=%n)" /etc/dovecot/dovecot-ldap.conf.ext
fi

# Set LDAP conf: pass_attrs (ex: pass_attrs = uid=user,userPassword=password)
if [ -n "$LDAP_USER_FIELD" ]; then
	setDovecotConf "pass_attrs" "$LDAP_USER_FIELD=user" /etc/dovecot/dovecot-ldap.conf.ext
fi

# Set SSL resource paths
if [ -n "$SSL_KEY_PATH" ]; then
	setDovecotConf "ssl_key" "<$SSL_KEY_PATH" /etc/dovecot/conf.d/10-ssl.conf
fi
if [ -n "$SSL_CERT_PATH" ]; then
	setDovecotConf "ssl_cert" "<$SSL_CERT_PATH" /etc/dovecot/conf.d/10-ssl.conf
fi

#########################################
# Generate SSL certification
#########################################

CERT_FOLDER="/etc/ssl/localcerts"
CSR_PATH="/tmp/imap.csr.pem"

if [ -n "$SSL_KEY_PATH" ]; then
	KEY_PATH=$SSL_KEY_PATH
else
	KEY_PATH="$CERT_FOLDER/imap.key.pem"
fi

if [ -n "$SSL_CERT_PATH" ]; then
	CERT_PATH=$SSL_CERT_PATH
else
	CERT_PATH="$CERT_FOLDER/imap.cert.pem"
fi

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