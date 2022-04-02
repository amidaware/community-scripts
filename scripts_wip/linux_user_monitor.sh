#!/bin/bash

# Monitor for users on Linux:

new="/opt/rmmscripts/users_new"
old="/opt/rmmscripts/users_old"

if [[ ! -e $old ]]; then
mkdir /opt/rmmscripts
cat /etc/passwd > $new
fi

mv $new $old
cat /etc/passwd > $new
diff <(cat $old) <(cat $new)
if [[ $? == 0 ]] ; then 
    echo "no users added or deleted"
else
    echo "user(s) added or deleted"
    exit 1
fi