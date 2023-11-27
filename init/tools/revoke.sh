#!/bin/bash
#

####################### Global Variables #######################
tool_dir=`dirname $0`

. $tool_dir/../settings.conf

name=$1
cert_type=${2:-server}
is_gm=$3

cert_name=$name.$conf_domain_suffix
cert_dir=$g_root_dir/${cert_type}s/$cert_name
ca_dir=
ca_conf=
if [ -n "$is_gm" ]; then
    cert_dir=$cert_dir/gm
    ca_dir=$g_gm_sub_ca_dir
    ca_conf=gm-sub-ca.conf
else
    cert_dir=$cert_dir/rsa
    ca_dir=$g_sub_ca_dir
    ca_conf=sub-ca.conf
fi

####################### Functions #######################

function usage {
    echo "Usage: $0 <name> [server|client] [is_gm]"
    echo "Example: $0 example server 1"
}

####################### Main #######################

# check parameters
if [ -z "$name" ]; then
    usage
    exit 1
fi

if [ "$cert_type" != "server" ] && [ "$cert_type" != "client" ]; then
    usage
    exit 1
fi

# check directory is exist
if [ ! -d $cert_dir ]; then
    echo "Error: $cert_dir is not exist"
    exit 1
fi

# get all certificate of named is cert.pem or enc-cert.pem in $cert_dir
certs=`ls $cert_dir | grep -E "cert.pem|enc-cert.pem"`

# revoke all certificate
cd $ca_dir

for cert in $certs; do
    echo "Revoke $cert_dir/$cert"
    $g_openssl ca -config $ca_conf -revoke $cert_dir/$cert -crl_reason unspecified
done
