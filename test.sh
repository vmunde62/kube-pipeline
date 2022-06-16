#!/bin/sh
file=/etc/vault.hcl

if ! test -f /var/lib/jenkins/.kube/config; then
    echo 'file not found'

else
    echo 'file found'
fi
