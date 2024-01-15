#!/bin/bash

####################### Global Variables #######################

tool_dir=`dirname $0`

source $CERTM_CF_SETTINGS

conf_passwd=$g_conf_password
conf_domain_name=
conf_gm_enable=
conf_type=clients
conf_cert_type=rsa

conf_csr=
conf_key=
conf_begin=
conf_end=

conf_enc_csr=
conf_enc_key=

cert_dir=
date_options=
g_clean_cert_dir=yes

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
    echo "  -k, --key <PRIVATE_KEY_FILE>            Private key file. If specified of CSR file(-r), will use this key file"
    echo "  -r, --request <CSR_FILE>                CSR file. If specified, will make certificate from CSR file"
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
        ca=$CERTM_PATH_SUB_CA_DIR
        conf=ca.conf
    else
        ca=$CERTM_PATH_GM_SUB_CA_DIR
        conf=ca.conf
    fi

    cd $ca

    for c in $certs
    do
        $CERTM_BIN_OPENSSL ca -config $conf -revoke $c -crl_reason unspecified
    done

    cd -

    if [ "$g_clean_cert_dir" == "yes" ]; then
        rm -rf $cert_dir

        domain_dir=`dirname $cert_dir`

        if [ -z "`ls -A $domain_dir`" ]; then
            rm -rf $domain_dir
        fi
    fi

    exit 1;
}

function convert_p12
{
    cert=$1
    key=$2
    out=$3

    $CERTM_BIN_OPENSSL pkcs12 -export \
        -in $cert \
        -inkey $key \
        -out $out \
        -password pass:$g_conf_p12_password
    [ $? -eq 0 ] || exit_on_error
}

function gen_rsa
{
    csr_config_file=$1
    gencsr=$2

    if [ "$conf_type" == "clients" ]; then
        cert_opts='-extensions client_ext'
    else
        req_opts='-reqexts server_req_ext'
        cert_opts='-extensions server_ext'
    fi

    if [ "$gencsr" == "yes" ]; then
        # gen key

        $CERTM_BIN_OPENSSL genpkey -out $conf_key \
                            -algorithm RSA \
                            -pkeyopt rsa_keygen_bits:2048
        [ $? -eq 0 ] || exit_on_error

        # gen csr
        $CERTM_BIN_OPENSSL req -new \
                        -config $csr_config_file \
                        -key $conf_key \
                        -out $conf_csr \
                        $req_opts
        [ $? -eq 0 ] || exit_on_error
    else
        # check key type wthether is RSA
        pkey_get_type $conf_key | grep -q rsa \
            || { echo "Key type must be RSA"; exit 1; }
    fi

    # gen cert

    cd $CERTM_PATH_SUB_CA_DIR

    $CERTM_BIN_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $conf_csr \
                      -out $cert_dir/cert.pem \
                      -notext \
                      -passin pass:$conf_passwd \
                      $cert_opts
    [ $? -eq 0 ] || exit_on_error

    cd -

    # verify whether cert was generated

    [ -f $cert_dir/cert.pem ] || exit_on_error

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error

    cat $CERTM_PATH_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error

    # gen p12
    convert_p12 $cert_dir/cert.pem $conf_key $cert_dir/cert.p12
    [ $? -eq 0 ] || exit_on_error
}

function gen_ecdsa
{
    csr_config_file=$1
    gencsr=$2

    if [ "$conf_type" == "clients" ]; then
        cert_opts='-extensions client_ext'
    else
        req_opts='-reqexts server_req_ext'
        cert_opts='-extensions server_ext'
    fi

    if [ "$gencsr" == "yes" ]; then
        # gen key

        $CERTM_BIN_OPENSSL genpkey -out $conf_key \
                            -algorithm EC \
                            -pkeyopt ec_paramgen_curve:P-256
        [ $? -eq 0 ] || exit_on_error

        # gen csr

        $CERTM_BIN_OPENSSL req -new \
                        -config $csr_config_file \
                        -key $conf_key \
                        -out $conf_csr \
                        $req_opts
        [ $? -eq 0 ] || exit_on_error
    else
        # check key type wthether is ecdsa
        pkey_get_type $conf_key | grep -q ecdsa \
            || { echo "Key type must be RSA"; exit 1; }
    fi

    # gen cert

    cd $CERTM_PATH_SUB_CA_DIR

    $CERTM_BIN_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $conf_csr \
                      -out $cert_dir/cert.pem \
                      -extensions server_ext \
                      -notext \
                      -passin pass:$conf_passwd \
                      $cert_opts
    [ $? -eq 0 ] || exit_on_error

    cd -

    # verify whether cert was generated

    [ -f $cert_dir/cert.pem ] || exit_on_error

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error

    cat $CERTM_PATH_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error

    # gen p12
    convert_p12 $cert_dir/cert.pem $conf_key $cert_dir/cert.p12
    [ $? -eq 0 ] || exit_on_error
}

function gen_gm
{
    csr_config_file=$1
    gencsr=$2

    if [ "$conf_type" == "clients" ]; then
        cert_opts='-extensions client_ext'
    else
        req_opts='-reqexts server_req_ext'
        cert_opts='-extensions server_ext'
    fi

    if [ "$gencsr" == "yes" ]; then
        # gen key

        $CERTM_BIN_OPENSSL ecparam -genkey \
                               -name SM2 \
                               -out $conf_key
        [ $? -eq 0 ] || exit_on_error

        # gen csr

        $CERTM_BIN_OPENSSL req -new \
                           -config $csr_config_file \
                           -key $conf_key \
                           -out $conf_csr \
                           $req_opts
        [ $? -eq 0 ] || exit_on_error
    else
        # check key type wthether is sm2
        pkey_get_type $conf_key | grep -q sm2 \
            || { echo "Key type must be SM2"; exit 1; }
    fi

    # gen cert

    cd $CERTM_PATH_GM_SUB_CA_DIR

    $CERTM_BIN_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $conf_csr \
                      -out $cert_dir/cert.pem \
                      -extensions server_gm_ext \
                      -md sm3 \
                      -notext \
                      -passin pass:$conf_passwd \
                      $cert_opts
    [ $? -eq 0 ] || exit_on_error

    cd -
    
    # Verify whether cert was generated

    [ -f $cert_dir/cert.pem ] || exit_on_error

    # gen cert chain

    cat $cert_dir/cert.pem >> $cert_dir/chain.pem
    cat $CERTM_PATH_GM_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem

    if [ "$gencsr" == "yes" ]; then
        # gen enc key

        $CERTM_BIN_OPENSSL ecparam -genkey \
                               -name SM2 \
                               -out $conf_enc_key
        [ $? -eq 0 ] || exit_on_error

        # gen enc csr

        $CERTM_BIN_OPENSSL req -new \
                           -config $csr_config_file \
                           -key $conf_enc_key \
                           -out $conf_enc_csr \
                           $req_opts
        [ $? -eq 0 ] || exit_on_error
    else
        # check key type wthether is sm2
        pkey_get_type $conf_enc_key | grep -q sm2 \
            || { echo "Key type must be SM2"; exit 1; }
    fi

    # gen enc cert

    cd $CERTM_PATH_GM_SUB_CA_DIR

    $CERTM_BIN_OPENSSL ca -config ca.conf \
                      $date_options \
                      -in $conf_enc_csr \
                      -out $cert_dir/enc-cert.pem \
                      -extensions server_gm_enc_ext \
                      -md sm3 \
                      -notext \
                      -passin pass:$conf_passwd \
                      $cert_opts
    [ $? -eq 0 ] || exit_on_error

    cd -

    # Verify whether enc-cert was generated

    [ -f $cert_dir/enc-cert.pem ] || exit_on_error

    # gen enc cert chain

    cat $cert_dir/enc-cert.pem >> $cert_dir/enc-chain.pem
    [ $? -eq 0 ] || exit_on_error

    cat $CERTM_PATH_GM_SUB_CA_DIR/ca.pem.crt >> $cert_dir/chain.pem
    [ $? -eq 0 ] || exit_on_error

    # gen p12
    convert_p12 $cert_dir/cert.pem $conf_key $cert_dir/cert.p12
    [ $? -eq 0 ] || exit_on_error

    convert_p12 $cert_dir/enc-cert.pem $conf_enc_key $cert_dir/enc-cert.p12
    [ $? -eq 0 ] || exit_on_error
}

# check csr and key file is matched
function check_csr
{
    csr=$1
    key=$2
    openssl_conf=$CERTM_PATH_SUB_CA_DIR/ca.conf

    [ -z "$conf_csr" ] && return 0

    # check csr file is existed
    if [ ! -f "$conf_csr" ];then
        echo "CSR file $conf_csr is not existed"
        return 1
    fi

    # check key file is existed
    [ -z "$conf_key" ] \
        && echo "private key must be specified, if csr file(-r) is specified" \
        && return 1

    if [ ! -f "$conf_key" ];then
        echo "Key file $conf_key is not existed"
        return 1
    fi

    t=`mktemp`
    if $CERTM_BIN_OPENSSL req \
        -config $openssl_conf \
        -in $conf_csr \
        -key $conf_key \
        -noout \
        -verify \
        2>&1 | tee $t | grep -q "verify OK";
    then
        rm $t
        return 0
    fi

    echo "csr error: `cat $t`"
    rm $t;

    return 1
}

function pkey_get_type
{
    key=$1

    # checking private key whether is existed
    if [ ! -f "$key" ]; then
        echo "Private key file ($key) not found."
        exit 1
    fi

    # get information of private key
    info=$($CERTM_BIN_OPENSSL pkey -in $key -text -noout 2>&1)

    # judge the type of private key
    if echo "$info" | grep -q "prime256v1"; then
        echo "ecdsa"
    elif echo "$info" | grep -q "ASN1 OID: SM2"; then
        echo "sm2"
    elif echo "$info" | grep -qP 'Private-Key: \(\d+ bit'; then
        echo "rsa"
    else
        echo "unknown"
    fi
}

####################### Main #######################

trap exit_on_error SIGINT

# parse options

if [ $# -eq 0 ]; then
    usage
fi

opt_gencsr=yes

while [ $# -gt 0 ]
do
    case $1 in
        -b|--begin)
            conf_begin=$2
            shift
            ;;
        -d|--debug)
            set -x
            g_clean_cert_dir=no
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
        -k|--key)
            conf_key=`cd $( dirname $2 ); pwd`/$( basename $2 )
            conf_enc_key=$conf_key
            shift
            ;;
        -r|--request)
            conf_csr=`cd $( dirname $2 ); pwd`/$( basename $2 )
            conf_enc_csr=$conf_csr
            opt_gencsr=no
            g_clean_cert_dir=no
            shift;
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

if [ -n "$conf_csr" ]; then
    check_csr $conf_csr $conf_key \
        || { echo "CSR '$conf_csr' and Key '$conf_key' is not matched"; exit 1; }

    cert_dir=`dirname $conf_csr`
else
    # check config
    if [ -z "$conf_domain_name" ]; then
        echo "Must specify domain name"
        usage
    fi

    dn=$conf_domain_name.$g_conf_domain_suffix
    export CERTM_INFO_DN=$dn

    if [ "$conf_type" == "servers" ]; then
        cert_dir=$CERTM_PATH_SERVER_DIR/$dn/$conf_cert_type
    else
        cert_dir=$CERTM_PATH_CLIENT_DIR/$dn/$conf_cert_type
    fi

    # mkdir directory

    if [ -d $cert_dir ]; then
        echo "$cert_dir was existed"
        exit 0
    fi

    mkdir -p $cert_dir

    # init csr

    csr_config_file=$cert_dir/csr.conf

    ## convert env to envsubst format, such as '$CERTM_INFO_CN $CERTM_INFO_ST ...'
    envs=`env | grep CERTM_INFO_ | cut -d '=' -f 1 | sed 's/\(.*\)/$\1/g' | tr '\n' ' '`

    envsubst "$envs" < $CERTM_CF_CSR > $csr_config_file

    # init default config
    conf_csr=$cert_dir/priv.csr
    conf_key=$cert_dir/privkey.pem
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

case $conf_cert_type in
    rsa)
        gen_rsa $csr_config_file $opt_gencsr
        ;;
    ecdsa)
        gen_ecdsa $csr_config_file $opt_gencsr
        ;;
    sm2)
        conf_gm_enable=1

        if [ "$opt_gencsr" == "yes" ]; then
            # init csr enc
            conf_enc_csr=$conf_csr
            conf_enc_key=$cert_dir/enc-privkey.pem
        fi

        gen_gm $csr_config_file $opt_gencsr
        ;;
    *)
        echo "Unknown certificate type: $conf_cert_type"
        usage
        ;;
esac
