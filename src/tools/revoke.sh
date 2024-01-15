#!/bin/bash
#

####################### Global Variables #######################
tool_dir=`dirname $0`

source $CERTM_CF_SETTINGS

conf_domain_name=
conf_gm_enable=
conf_type=clients
conf_cert_type=rsa

cert_name=

####################### Functions #######################

source $CERTM_PATH_ROOT_DIR/tools-dev/base_for_bash.func

function usage {
    echo "Usage: certm-revoke [OPTIONS] <domain_name>"
    echo "Options:"
    echo "  -g, --gm                        GM certificate(deprecated, use \"-t sm2\" instead)"
    echo "  -h, --help                      Show help"
    echo "  -s, --server                    Server certificate, default is client"
    echo "  -t, --type <rsa | ecdsa | sm2>  Certificate Key type, default is 'rsa'"
    echo ""
    echo "Example: certm-revoke cert1"
}

function revoke {
    ca_dir=$1
    ca_conf=ca.conf

    # get all certificate of named is cert.pem or enc-cert.pem in $cert_dir
    certs=`ls $cert_dir | grep -E "cert.pem|enc-cert.pem"`

    # revoke all certificate
    cd $ca_dir

    g_d_err_title="Revoke"

    for cert in $certs; do
        $CERTM_BIN_OPENSSL ca -config $ca_conf -revoke $cert_dir/$cert -crl_reason unspecified >> $CERTM_LOG_FILE 2>&1
        [ $? -eq 0 ] || d_err_exit "Revoke $cert_dir/$cert"

        d_success_info "Revoke $cert_dir/$cert"
    done
}

####################### Main #######################

# Parse parameters

while [ -n "$1" ]; do
    case "$1" in
        -g|--gm)
            conf_cert_type=sm2
            ;;
        -h|--help)
            usage
            exit 0
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
    cert_dir=$CERTM_PATH_SERVER_DIR/$dn/$conf_cert_type
else
    cert_dir=$CERTM_PATH_CLIENT_DIR/$dn/$conf_cert_type
fi

# check directory is exist
if [ ! -d $cert_dir ]; then
    echo "Error: $cert_dir is not exist"
    exit 1
fi

# revoke certificate

case $conf_cert_type in
    rsa)
        ca_dir=$CERTM_PATH_SUB_CA_DIR
        revoke $ca_dir
        ;;
    ecdsa)
        ca_dir=$CERTM_PATH_SUB_CA_DIR
        revoke $ca_dir
        ;;
    sm2)
        ca_dir=$CERTM_PATH_GM_SUB_CA_DIR
        revoke $ca_dir
        ;;
    *)
        echo "Unknown certificate type: $conf_cert_type"
        usage
        ;;
esac