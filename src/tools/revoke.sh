#!/bin/bash
#

####################### Global Variables #######################
tool_dir=`dirname $0`

source $CERTM_CONFIG_FILE

conf_name=$1
conf_type=${2:-client}
conf_is_gm=

cert_name=
ca_dir=
ca_conf=ca.conf

####################### Functions #######################

source $CERTM_ROOT_DIR/tools-dev/base_for_bash.func

function usage {
    echo "Usage: certm-revoke [OPTIONS] <domain_name>"
    echo "Options:"
    echo "  -h, --help          Show help"
    echo "  -s, --server        Server certificate, default is client"
    echo "  -g, --gm            GM Certificate, default is rsa"
    echo "Example: $0 example server 1"
}

####################### Main #######################

# Parse parameters

while [ -n "$1" ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--server)
            conf_type=server
            ;;
        -g|--gm)
            conf_is_gm=1
            ;;
        *)
            # whether is invalid option
            if [[ "$1" =~ ^-.* ]]; then
                echo "Unknown option: $1"
                usage
            fi

            if [ -n "$name" ]; then
                echo "Unknown option: $1"
                usage
            fi

            name=$1
            ;;
    esac
    shift
done

cert_name=$name.$g_conf_domain_suffix
cert_dir=$CERTM_OUTPUT_DIR/${conf_type}s/$cert_name

if [ -n "$conf_is_gm" ]; then
    cert_dir=$cert_dir/gm
    ca_dir=$CERTM_GM_SUB_CA_DIR
else
    cert_dir=$cert_dir/rsa
    ca_dir=$CERTM_SUB_CA_DIR
fi

# check parameters
if [ -z "$conf_name" ]; then
    usage
    exit 1
fi

if [ "$conf_type" != "server" ] && [ "$conf_type" != "client" ]; then
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

g_d_err_title="Revoke"

for cert in $certs; do
    $CERTM_OPENSSL ca -config $ca_conf -revoke $cert_dir/$cert -crl_reason unspecified >> $CERTM_LOG_FILE 2>&1
    [ $? -eq 0 ] || d_err_exit "Revoke $cert_dir/$cert"

    d_success_info "Revoke $cert_dir/$cert"
done
