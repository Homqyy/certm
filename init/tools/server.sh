#!/bin/bash

################################################# init

tool_dir=`dirname $0`

. $tool_dir/../settings.conf

conf_passwd=root
conf_domain_name=
conf_gm_enable=
cert_dir=

################################################# function

function usage
{
    echo "Usage: $0 <domain_name> [bool_gm]"
}

function exit_on_error
{
    echo "Cleanup..."

    [ -d $cert_dir ] || exit 1

    # revoke

    certs=`find $cert_dir -name "*cert.pem"`
    ca=
    conf=

    if [ -z "$conf_gm_enable" ]; then
        ca=$g_sub_ca_dir
        conf=sub-ca.conf
    else
        ca=$g_gm_sub_ca_dir
        conf=gm-sub-ca.conf
    fi

    cd $ca

    for $c in certs
    do
        $g_openssl ca -config $conf -revoke $c -crl_reason unspecified
    done

    cd -

    # rm -rf $cert_dir

    exit 1;
}

function gen_rsa
{
    # gen key

    $g_openssl genpkey -out $cert_dir/privkey.pem -algorithm RSA -pkeyopt rsa_keygen_bits:2048
    [ $? -eq 0 ] || exit_on_error 1

    # gen csr

    $g_openssl req -new -config $cert_dir/csr.conf -key $cert_dir/privkey.pem -out $cert_dir/priv.csr
    [ $? -eq 0 ] || exit_on_error 1

    # gen cert

    cd $g_sub_ca_dir

    $g_openssl ca -config sub-ca.conf -days 1095 -in $cert_dir/priv.csr -out $cert_dir/cert.pem -extensions server_ext -notext -passin pass:$conf_passwd
    [ $? -ne 0 ] && cd - && exit_on_error 1

    cd -

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error 1

    cat $g_sub_ca_dir/sub-ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error 1
}

function gen_gm
{
    # gen key

    $g_openssl ecparam -genkey -name SM2 -out $cert_dir/privkey.pem
    [ $? -eq 0 ] || exit_on_error 1

    # gen csr

    $g_openssl req -new -config $cert_dir/csr.conf -key $cert_dir/privkey.pem -out $cert_dir/priv.csr
    [ $? -eq 0 ] || exit_on_error 1

    # gen cert

    cd $g_gm_sub_ca_dir

    $g_openssl ca -config gm-sub-ca.conf -days 1095 -in $cert_dir/priv.csr -out $cert_dir/cert.pem -extensions server_gm_ext -md sm3 -notext -passin pass:$conf_passwd
    [ $? -ne 0 ] && cd - && exit_on_error 1

    cd -

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    cat $g_gm_sub_ca_dir/gm-sub-ca.pem.crt >> $cert_dir/chain.pem

    # gen enc key

    $g_openssl ecparam -genkey -name SM2 -out $cert_dir/enc-privkey.pem
    [ $? -eq 0 ] || exit_on_error 1

    # gen enc csr

    $g_openssl req -new -config $cert_dir/enc-csr.conf -key $cert_dir/enc-privkey.pem -out $cert_dir/enc-priv.csr
    [ $? -eq 0 ] || exit_on_error 1

    # gen enc cert

    cd $g_gm_sub_ca_dir

    $g_openssl ca -config gm-sub-ca.conf -days 1095 -in $cert_dir/enc-priv.csr -out $cert_dir/enc-cert.pem -extensions server_gm_enc_ext -md sm3 -notext -passin pass:$conf_passwd
    [ $? -ne 0 ] && cd - && exit_on_error 1

    cd -

    # gen enc cert chain

    cat $cert_dir/enc-cert.pem >> $cert_dir/enc-chain.pem
    [ $? -eq 0 ] || exit_on_error 1

    cat $g_gm_sub_ca_dir/gm-sub-ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error 1
}

################################################# main

trap exit_on_error SIGINT

# parse arguments

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

conf_domain_name=$1
conf_gm_enable=$2
conf_type_name=

if [ -n "$conf_gm_enable" ]; then
    conf_type_name=gm
else
    conf_type_name=rsa
fi

cert_dir=$g_server_dir/$conf_domain_name/$conf_type_name

# mkdir directory

if [ -d $cert_dir ]; then
    echo "$cert_dir was existed"
    exit 0
fi

mkdir $cert_dir

# set csr config

cp $g_csr_conf $cert_dir/csr.conf

sed -i "s/{{domain_name}}/$conf_domain_name/g" $cert_dir/csr.conf
sed -i "s/{{organization}}/$conf_organization/g" $cert_dir/csr.conf
sed -i "s/{{organization_unit}}/$conf_organization_unit/g" $cert_dir/csr.conf

if [ -n "$conf_gm_enable" ]; then
    cp $g_enc_csr_conf $cert_dir/enc-csr.conf
    sed -i "s/{{domain_name}}/$conf_domain_name/g" $cert_dir/enc-csr.conf
    sed -i "s/{{organization}}/$conf_organization/g" $cert_dir/enc-csr.conf
    sed -i "s/{{organization_unit}}/$conf_organization_unit/g" $cert_dir/enc-csr.conf
fi

if [[ -z "$conf_gm_enable" ]]; then
    gen_rsa
else
    gen_gm
fi


