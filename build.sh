#!/bin/bash

################# Global Variables #################

g_root_dir=`cd $(dirname $0); pwd`
g_tongsuo_dir=$g_root_dir/tongsuo
g_tongsuo_install_dir=/usr/local/tongsuo
g_src_dir=$g_root_dir/src
g_output_dir=$g_root_dir/output
g_log_file=$g_output_dir/build.log
g_openssl=
g_debug=
g_sh=bash
g_export_envs="CERTM_ROOT_DIR CERTM_OUTPUT_DIR \
        CERTM_LOG_FILE CERTM_CONFIG_FILE \
        CERTM_OPENSSL \
        CERTM_CSR_CONF \
        CERTM_ENC_CSR_CONF \
        CERTM_ROOT_CA_DIR \
        CERTM_SUB_CA_DIR \
        CERTM_GM_ROOT_CA_DIR \
        CERTM_GM_SUB_CA_DIR \
        CERTM_CLIENT_DIR \
        CERTM_SERVER_DIR"

################# Functions #################

git submodule init && git submodule update || (echo "Failed to init submodules"; exit 1)

source $g_root_dir/tools-dev/base_for_bash.func

function usage
{
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  -c, --clean     Clean all the build files: dependencies + certm"
    echo "  -d, --debug     Enable debug mode"
    echo "  -i, --install   Install certm"
    echo "  -u, --uninstall Uninstall certm"
    echo "  -r, --rebuild   Rebuild certm"
}

function clean
{
    rm -rf $g_output_dir

    # clean tongsuo
    if [ -d $g_tongsuo_dir ]; then
        cd $g_tongsuo_dir

        git clean -xf . > /dev/null 2>&1
        git checkout . > /dev/null 2>&1

        [ -f .build ] && rm .build
        [ -f .system ] && rm .system

        cd - >& /dev/null
    fi

    d_success_info "Clean all the build files"
}

function build_tongsuo
{
    g_openssl=$g_tongsuo_dir/apps/openssl

    [ -d $g_tongsuo_dir ] || return 1

    [ -f $g_tongsuo_dir/.build ] && return 0

    rpath="-Wl,-rpath,$g_tongsuo_dir"

    cd $g_tongsuo_dir

    # TODO: support install to system, but need sudo
    ./config --prefix=$g_tongsuo_install_dir $rpath no-shared enable-ec_elgamal enable-paillier enable-ntls >> $g_log_file 2>&1 \
        && make >> $g_log_file 2>&1

    if [ $? != 0 ]; then
        cd - >& /dev/null
	return 1
    fi

    cd - >& /dev/null

    touch $g_tongsuo_dir/.build

    d_success_info "Build tongsuo"

    return 0
}

function build_certm
{
    export g_root_dir
    export g_output_dir
    export g_log_file
    export g_openssl
    export g_config_file=$g_root_dir/settings.conf
    export g_csr_conf=$g_src_dir/assets/csr.conf
    export g_enc_csr_conf=$g_src_dir/assets/gm-enc-csr.conf
    export g_root_ca_dir=$g_output_dir/root-ca
    export g_sub_ca_dir=$g_output_dir/sub-ca
    export g_gm_root_ca_dir=$g_output_dir/gm-root-ca
    export g_gm_sub_ca_dir=$g_output_dir/gm-sub-ca
    export g_client_dir=$g_output_dir/clients
    export g_server_dir=$g_output_dir/servers

    [ -f $g_output_dir/.build ] && return 0

    $g_sh $g_src_dir/init.sh

    touch $g_output_dir/.build

    d_success_info "Build certm"

    return 0
}

function uninstall_certm
{
    env_file=$g_output_dir/.env

    if [ -f $env_file ]; then
        # whether is installed
        grep -q "# certm install start: v1" $env_file || return 0

        # remove install from ~/.bashrc
        sed -i '/# certm install start: v1/,/# certm insatll end: v1/d' $env_file
    fi

    d_success_info "Uninstall certm"
}

function install_certm
{
    env_file=$g_output_dir/.env

    if [ -f $env_file ]; then
        # whether is installed
        grep -q "# certm install start: v1" $env_file && return 0

        # backup
        cp $env_file $env_file.bak
    fi

    cat >> $env_file << EOF
# certm install start: v1
alias "certm-mkcert=$g_root_dir/src/tools/mkcert.sh"
alias "certm-revoke=$g_root_dir/src/tools/revoke.sh"
alias "certm-gencrl=$g_root_dir/src/tools/gencrl.sh"
alias "certm-genca=$g_root_dir/src/tools/genca.sh"

export CERTM_ROOT_DIR=$g_root_dir
export CERTM_OUTPUT_DIR=$g_output_dir
export CERTM_LOG_FILE=$g_log_file
export CERTM_CONFIG_FILE=$g_config_file
export CERTM_OPENSSL=$g_openssl
export CERTM_CSR_CONF=$g_csr_conf
export CERTM_ENC_CSR_CONF=$g_enc_csr_conf
export CERTM_ROOT_CA_DIR=$g_root_ca_dir
export CERTM_SUB_CA_DIR=$g_sub_ca_dir
export CERTM_GM_ROOT_CA_DIR=$g_gm_root_ca_dir
export CERTM_GM_SUB_CA_DIR=$g_gm_sub_ca_dir
export CERTM_CLIENT_DIR=$g_client_dir
export CERTM_SERVER_DIR=$g_server_dir
# certm install end: v1
EOF

    d_success_info "Install certm"
}

################# Main #################

# Parse command line options

g_d_err_title="OPTIONS"

opt_install=
opt_uninstall=
opt_clean=

while [ $# -gt 0 ]
do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -c|--clean)
            opt_clean=1
            shift
            ;;
        -d|--debug)
            set -x
            g_debug=1
            g_sh="bash -x"
            shift
            ;;
        -i|--install)
            opt_install=1
            shift
            ;;
        -u|--uninstall)
            opt_uninstall=1
            shift
            ;;
        -r|--rebuild)
            rm -f $g_output_dir/.build
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -n "$opt_uninstall" ]; then
    uninstall_certm
    exit 0
fi

if [ -n "$opt_clean" ]; then
    clean
    exit 0
fi

g_d_err_title="INIT"

[ -d $g_output_dir ] || mkdir $g_output_dir
[ -f $g_log_file ] || touch $g_log_file

d_success_info "Init"

g_d_err_title="BUILD"

build_tongsuo || d_err_exit "Build tongsuo"

build_certm || d_err_exit "Build certm"

g_d_err_title="INSTALL"

if [ -n "$opt_install" ]; then
    install_certm || d_err_exit "Install certm"
fi

g_d_err_title="DONE"