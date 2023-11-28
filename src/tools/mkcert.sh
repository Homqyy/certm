#!/bin/bash

####################### Global Variables #######################

tool_dir=`dirname $0`

source $CERTM_CONFIG_FILE

conf_passwd=root
conf_domain_name=
conf_gm_enable=
conf_type=clients
conf_cert_type=rsa
conf_begin=
conf_end=

cert_dir=
date_options=

####################### Functions #######################

function usage
{
    echo "Usage: $0 [OPTIONS] <domain_name>"
    echo "Options:"
    echo "  -h, --help          Show help"
    echo "  -g, --gm            Enable gm"
    echo "  -s, --server        Server certificate, default is client"
    echo "  -b, --begin <DATE>  Begin date, default is now"
    echo "  -e, --end   <DATE>  End date, default is 1095 days"
    echo ""
    echo "DATE: format is YYYYMMDDHHMMSSZ, such as 20201027120000Z"
    echo ""
    echo "Example: $0 example"

    exit 1
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

    for c in $certs
    do
        $CERTM_OPENSSL ca -config $conf -revoke $c -crl_reason unspecified
    done

    cd -

    exit 1;
}

function gen_rsa
{
    # gen key

    $CERTM_OPENSSL genpkey -out $cert_dir/privkey.pem -algorithm RSA -pkeyopt rsa_keygen_bits:2048
    [ $? -eq 0 ] || exit_on_error 1

    # gen csr

    $CERTM_OPENSSL req -new -config $cert_dir/csr.conf -key $cert_dir/privkey.pem -out $cert_dir/priv.csr
    [ $? -eq 0 ] || exit_on_error 1

    # gen cert

    cd $g_sub_ca_dir

    $CERTM_OPENSSL ca -config sub-ca.conf $date_options -in $cert_dir/priv.csr -out $cert_dir/cert.pem -extensions server_ext -notext -passin pass:$conf_passwd
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

    $CERTM_OPENSSL ecparam -genkey -name SM2 -out $cert_dir/privkey.pem
    [ $? -eq 0 ] || exit_on_error 1

    # gen csr

    $CERTM_OPENSSL req -new -config $cert_dir/csr.conf -key $cert_dir/privkey.pem -out $cert_dir/priv.csr
    [ $? -eq 0 ] || exit_on_error 1

    # gen cert

    cd $g_gm_sub_ca_dir

    $CERTM_OPENSSL ca -config gm-sub-ca.conf $date_options -in $cert_dir/priv.csr -out $cert_dir/cert.pem -extensions server_gm_ext -md sm3 -notext -passin pass:$conf_passwd
    [ $? -ne 0 ] && cd - && exit_on_error 1

    cd -

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    cat $g_gm_sub_ca_dir/gm-sub-ca.pem.crt >> $cert_dir/chain.pem

    # gen enc key

    $CERTM_OPENSSL ecparam -genkey -name SM2 -out $cert_dir/enc-privkey.pem
    [ $? -eq 0 ] || exit_on_error 1

    # gen enc csr

    $CERTM_OPENSSL req -new -config $cert_dir/enc-csr.conf -key $cert_dir/enc-privkey.pem -out $cert_dir/enc-priv.csr
    [ $? -eq 0 ] || exit_on_error 1

    # gen enc cert

    cd $g_gm_sub_ca_dir

    $CERTM_OPENSSL ca -config gm-sub-ca.conf $date_options -in $cert_dir/enc-priv.csr -out $cert_dir/enc-cert.pem -extensions server_gm_enc_ext -md sm3 -notext -passin pass:$conf_passwd
    [ $? -ne 0 ] && cd - && exit_on_error 1

    cd -

    # gen enc cert chain

    cat $cert_dir/enc-cert.pem >> $cert_dir/enc-chain.pem
    [ $? -eq 0 ] || exit_on_error 1

    cat $g_gm_sub_ca_dir/gm-sub-ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error 1
}

####################### Main #######################

trap exit_on_error SIGINT

# parse options

if [ $# -eq 0 ]; then
    usage
fi

while [ $# -gt 0 ]
do
    case $1 in
        -h|--help)
            usage
            ;;
        -g|--gm)
            conf_gm_enable=1
            conf_cert_type=gm
            ;;
        -s|--server)
            conf_type=servers
            ;;
        -b|--begin)
            conf_begin=$2
            shift
            ;;
        -e|--end)
            conf_end=$2
            shift
            ;;
        *)
            conf_domain_name=$1
            ;;
    esac
    shift
done

dn=$conf_domain_name.$conf_domain_suffix

if [ "$conf_type" == "servers" ]; then
    cert_dir=$g_server_dir/$dn/$conf_cert_type
else
    cert_dir=$g_client_dir/$dn/$conf_cert_type
fi

# mkdir directory

if [ -d $cert_dir ]; then
    echo "$cert_dir was existed"
    exit 0
fi

mkdir -p $cert_dir

# set csr config

cp $CERTM_CSR_CONF $cert_dir/csr.conf

sed -i "s/{{domain_name}}/$dn/g" $cert_dir/csr.conf
sed -i "s/{{organization}}/$g_conf_organization/g" $cert_dir/csr.conf
sed -i "s/{{organization_unit}}/$g_conf_organization_unit/g" $cert_dir/csr.conf

if [ -n "$conf_gm_enable" ]; then
    cp $CERTM_ENC_CSR_CONF $cert_dir/enc-csr.conf
    sed -i "s/{{domain_name}}/$dn/g" $cert_dir/enc-csr.conf
    sed -i "s/{{organization}}/$g_conf_organization/g" $cert_dir/enc-csr.conf
    sed -i "s/{{organization_unit}}/$g_conf_organization_unit/g" $cert_dir/enc-csr.conf
fi

# validate default is +1095 days, else is from $conf_begin to $conf_end
if [ -n "$conf_begin" -a -n "$conf_end" ]; then
    date_options="-startdate $conf_begin -enddate $conf_end"
elif [ -n "$conf_begin" ]; then
    date_options="-startdate $conf_begin -days 1095"
elif [ -n "$conf_end" ]; then
    date_options="-enddate $conf_end"
else
    date_options="-days 1095"
fi

if [[ -z "$conf_gm_enable" ]]; then
    gen_rsa
else
    gen_gm
fi


