#!/bin/bash

################# Global Variables #################

g_root_dir=`cd $(dirname $0); pwd`
g_tongsuo_dir=$g_root_dir/tongsuo
g_tongsuo_install_dir=/usr/local/tongsuo
g_src_dir=$g_root_dir/src
g_output_dir=$g_root_dir/output
g_log_file=$g_output_dir/build.log
g_debug=
g_restart=
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

        [ -f .installed ] && rm .installed

        cd -

        # TODO: uninstall tongsuo from system

        # [ -d $g_tongsuo_install_dir ] && rm -rf $g_tongsuo_install_dir
    fi
}

function build_tongsuo
{
    [ -d $g_tongsuo_dir ] || return 1

    [ -f $g_tongsuo_dir/.installed ] && return 0

    cd $g_tongsuo_dir

    # TODO: support install to system, but need sudo
    ./config --prefix=$g_tongsuo_install_dir -Wl,-rpath,$g_tongsuo_dir enable-ec_elgamal enable-paillier enable-ntls >> $g_log_file 2>&1 \
        && make >> $g_log_file 2>&1 \
        || (cd -; return 1)

    cd -

    touch $g_tongsuo_dir/.installed

    return 0
}

function build_certm
{
    export g_root_dir
    export g_output_dir
    export g_log_file
    export g_config_file=$g_root_dir/settings.conf
    export g_openssl=$g_tongsuo_dir/apps/openssl
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
}

function install_certm
{
    # whether is installed
    grep -q "# certm install start: v1" ~/.bashrc && return 0

    if [ -f ~/.bashrc ]; then
        cp ~/.bashrc ~/.bashrc.bak
    fi

    echo "# certm install start: v1" >> ~/.bashrc

    # set alias to ~/.bashrc

    echo "alias certm-mkcert=$g_root_dir/src/tools/mkcert.sh" >> ~/.bashrc
    echo "alias certm-revoke=$g_root_dir/src/tools/revoke.sh" >> ~/.bashrc
    echo "alias certm-gencrl=$g_root_dir/src/tools/gencrl.sh" >> ~/.bashrc
    echo "alias certm-genca=$g_root_dir/src/tools/genca.sh" >> ~/.bashrc

    # export environment variables to ~/.bashrc

    CERTM_ROOT_DIR=$g_root_dir
    CERTM_OUTPUT_DIR=$g_output_dir
    CERTM_LOG_FILE=$g_log_file
    CERTM_CONFIG_FILE=$g_config_file
    CERTM_OPENSSL=$g_openssl
    CERTM_CSR_CONF=$g_csr_conf
    CERTM_ENC_CSR_CONF=$g_enc_csr_conf
    CERTM_ROOT_CA_DIR=$g_root_ca_dir
    CERTM_SUB_CA_DIR=$g_sub_ca_dir
    CERTM_GM_ROOT_CA_DIR=$g_gm_root_ca_dir
    CERTM_GM_SUB_CA_DIR=$g_gm_sub_ca_dir
    CERTM_CLIENT_DIR=$g_client_dir
    CERTM_SERVER_DIR=$g_server_dir

    for e in $g_export_envs
    do
        echo "export $e=${!e}" >> ~/.bashrc
    done

    echo "# certm install end: v1" >> ~/.bashrc
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
    # whether is installed
    if grep -q "# certm install start: v1" ~/.bashrc
    then
        # remove install from ~/.bashrc
        sed -i '/# certm install start: v1/,/# certm insatll end: v1/d' ~/.bashrc
    fi
    g_restart=1
    d_success_info "Uninstall certm"
fi

if [ -n "$opt_clean" ]; then
    clean
    d_success_info "Clean all the build files"
fi

g_d_err_title="INIT"

[ -d $g_output_dir ] || mkdir $g_output_dir
[ -f $g_log_file ] || touch $g_log_file

d_success_info "Init"

g_d_err_title="BUILD"

build_tongsuo || d_err_exit "Build tongsuo"

d_success_info "Build tongsuo"

build_certm || d_err_exit "Build certm"

d_success_info "Build certm"

g_d_err_title="INSTALL"

if [ -n "$opt_install" ]; then
    install_certm
    d_success_info "Install certm"
    g_restart=1
fi

g_d_err_title="DONE"

if [ -n "$g_restart" ]; then
    d_success_info "Restart bash"

    # clean CERTM_* environment variables
    for e in $g_export_envs
    do
        unset $e
    done

    exec bash
fi
