#!/bin/bash -e

AUTHORIZED_KEYS_FILE="/etc/ssh/authorized_keys"

touch $AUTHORIZED_KEYS_FILE

for i in $( curl --silent http://169.254.169.254/latest/meta-data/public-keys/ | cut -f1 -d= ); do
	PUBLIC_KEY=$( curl --silent "http://169.254.169.254/latest/meta-data/public-keys/$i/openssh-key" )
	>&2 echo "$i: $PUBLIC_KEY"
	echo $PUBLIC_KEY > $AUTHORIZED_KEYS_FILE
done
