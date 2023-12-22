#!/bin/bash

####################### Global Variables #######################

tool_dir=`dirname $0`

source $CERTM_CONFIG_FILE

conf_passwd=$g_conf_password
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
    echo "Usage: certm-mkcert [OPTIONS] <domain_name>"
    echo "Options:"
    echo "  -b, --begin <DATE>                      Begin date, default is now"
    echo "  -d, --debug                             Enable debug mode"
    echo "  -e, --end   <DATE>                      End date, default is 1095 days"
    echo "  -g, --gm                                GM certificate (deprecated, use \"-t sm2\" instead)"
    echo "  -h, --help                              Show help"
    echo "  -s, --server                            Server certificate, default is client"
    echo "  -t, --type  <rsa | ecdsa | sm2>         Certificate Key type, default is 'rsa'"
    echo ""
    echo "DATE: format is YYYYMMDDHHMMSSZ, such as 20201027120000Z"
    echo ""
    echo "Example: certm-mkcert cert1"

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
        ca=$CERTM_SUB_CA_DIR
        conf=ca.conf
    else
        ca=$CERTM_GM_SUB_CA_DIR
        conf=ca.conf
    fi

    cd $ca

    for c in $certs
    do
        $CERTM_OPENSSL ca -config $conf -revoke $c -crl_reason unspecified
    done

    cd -

    rm -rf $cert_dir

    domain_dir=`dirname $cert_dir`

    if [ -z "`ls -A $domain_dir`" ]; then
        rm -rf $domain_dir
    fi

    exit 1;
}

function gen_rsa
{
    # gen key

    $CERTM_OPENSSL genpkey -out $cert_dir/privkey.pem \
                           -algorithm RSA \
                           -pkeyopt rsa_keygen_bits:2048
    [ $? -eq 0 ] || exit_on_error

    # gen csr

    $CERTM_OPENSSL req -new \
                       -config $cert_dir/csr.conf \
                       -key $cert_dir/privkey.pem \
                       -out $cert_dir/priv.csr
    [ $? -eq 0 ] || exit_on_error

    # gen cert

    cd $CERTM_SUB_CA_DIR

    $CERTM_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $cert_dir/priv.csr \
                      -out $cert_dir/cert.pem \
                      -extensions server_ext \
                      -notext \
                      -passin pass:$conf_passwd
    [ $? -eq 0 ] || exit_on_error

    cd -

    # verify whether cert was generated

    [ -f $cert_dir/cert.pem ] || exit_on_error

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error

    cat $CERTM_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error
}

function gen_ecdsa
{
    # gen key

    $CERTM_OPENSSL genpkey -out $cert_dir/privkey.pem \
                           -algorithm EC \
                           -pkeyopt ec_paramgen_curve:P-256
    [ $? -eq 0 ] || exit_on_error

    # gen csr

    $CERTM_OPENSSL req -new \
                       -config $cert_dir/csr.conf \
                       -key $cert_dir/privkey.pem \
                       -out $cert_dir/priv.csr
    [ $? -eq 0 ] || exit_on_error

    # gen cert

    cd $CERTM_SUB_CA_DIR

    $CERTM_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $cert_dir/priv.csr \
                      -out $cert_dir/cert.pem \
                      -extensions server_ext \
                      -notext \
                      -passin pass:$conf_passwd
    [ $? -eq 0 ] || exit_on_error

    cd -

    # verify whether cert was generated

    [ -f $cert_dir/cert.pem ] || exit_on_error

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error

    cat $CERTM_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error
}

function gen_gm
{
    # gen key

    $CERTM_OPENSSL ecparam -genkey \
                           -name SM2 \
                           -out $cert_dir/privkey.pem
    [ $? -eq 0 ] || exit_on_error

    # gen csr

    $CERTM_OPENSSL req -new \
                       -config $cert_dir/csr.conf \
                       -key $cert_dir/privkey.pem \
                       -out $cert_dir/priv.csr
    [ $? -eq 0 ] || exit_on_error

    # gen cert

    cd $CERTM_GM_SUB_CA_DIR

    $CERTM_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $cert_dir/priv.csr \
                      -out $cert_dir/cert.pem \
                      -extensions server_gm_ext \
                      -md sm3 \
                      -notext \
                      -passin pass:$conf_passwd
    [ $? -eq 0 ] || exit_on_error

    cd -
    
    # Verify whether cert was generated

    [ -f $cert_dir/cert.pem ] || exit_on_error

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    cat $CERTM_GM_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem

    # gen enc key

    $CERTM_OPENSSL ecparam -genkey \
                           -name SM2 \
                           -out $cert_dir/enc-privkey.pem
    [ $? -eq 0 ] || exit_on_error

    # gen enc csr

    $CERTM_OPENSSL req -new \
                       -config $cert_dir/enc-csr.conf \
                       -key $cert_dir/enc-privkey.pem \
                       -out $cert_dir/enc-priv.csr
    [ $? -eq 0 ] || exit_on_error

    # gen enc cert

    cd $CERTM_GM_SUB_CA_DIR

    $CERTM_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $cert_dir/enc-priv.csr \
                      -out $cert_dir/enc-cert.pem \
                      -extensions server_gm_enc_ext \
                      -md sm3 \
                      -notext \
                      -passin pass:$conf_passwd
    [ $? -eq 0 ] || exit_on_error

    cd -

    # Verify whether enc-cert was generated

    [ -f $cert_dir/enc-cert.pem ] || exit_on_error

    # gen enc cert chain

    cat $cert_dir/enc-cert.pem >> $cert_dir/enc-chain.pem
    [ $? -eq 0 ] || exit_on_error

    cat $CERTM_GM_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error
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
        -b|--begin)
            conf_begin=$2
            shift
            ;;
        -d|--debug)
            set -x
            ;;
        -e|--end)
            conf_end=$2
            shift
            ;;
        -g|--gm)
            conf_cert_type=sm2
            ;;
        -h|--help)
            usage
            ;;
        -s|--server)
            conf_type=servers
            ;;
        -t|--type)
            conf_cert_type=$2
            shift
            ;;
        *)
            # whether is invalid option
            if [[ "$1" =~ ^-.* ]]; then
                echo "Unknown option: $1"
                usage
            fi

            if [ -n "$conf_domain_name" ]; then
                echo "Unknown option: $1"
                usage
            fi

            conf_domain_name=$1
            ;;
    esac
    shift
done


if [ -z "$conf_domain_name" ]; then
    echo "Must specify domain name"
    usage
fi

dn=$conf_domain_name.$g_conf_domain_suffix

if [ "$conf_type" == "servers" ]; then
    cert_dir=$CERTM_SERVER_DIR/$dn/$conf_cert_type
else
    cert_dir=$CERTM_CLIENT_DIR/$dn/$conf_cert_type
fi

# mkdir directory

if [ -d $cert_dir ]; then
    echo "$cert_dir was existed"
    exit 0
fi

mkdir -p $cert_dir

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

# init config

cp $CERTM_CSR_CONF $cert_dir/csr.conf
sed -i "s/{{domain_name}}/$dn/g" $cert_dir/csr.conf
sed -i "s/{{organization}}/$g_conf_organization/g" $cert_dir/csr.conf
sed -i "s/{{organization_unit}}/$g_conf_organization_unit/g" $cert_dir/csr.conf

case $conf_cert_type in
    rsa)
        gen_rsa
        ;;
    ecdsa)
        gen_ecdsa
        ;;
    sm2)
        conf_gm_enable=1

        # enc
        cp $CERTM_ENC_CSR_CONF $cert_dir/enc-csr.conf
        sed -i "s/{{domain_name}}/$dn/g" $cert_dir/enc-csr.conf
        sed -i "s/{{organization}}/$g_conf_organization/g" $cert_dir/enc-csr.conf
        sed -i "s/{{organization_unit}}/$g_conf_organization_unit/g" $cert_dir/enc-csr.conf

        gen_gm
        ;;
    *)
        echo "Unknown certificate type: $conf_cert_type"
        usage
        ;;
esac
