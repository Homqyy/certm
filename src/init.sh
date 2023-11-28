#!/bin/bash
#
# Author: Homqyy
#
# Data: 2020/10/27
#
# -----------------------------------------------------
#
# Description:
#     build root-ca, sub-ca, gm-root-ca, gm-sub-ca
#

################## Global Variables ##################

bin_dir=$( cd `dirname $0`; pwd )

source $g_config_file
source $g_root_dir/tools-dev/base_for_bash.func

root=$g_output_dir

conf_passwd=root

################## Functions ##################

function init_ca
{
    ca_name=$1
    ca_temp_conf=$2

    [ -d $root/$ca_name ] && rm -rf $root/$ca_name

    mkdir $root/$ca_name

    cp $ca_temp_conf $root/$ca_name/ca.conf

    sed -i "s/{{name}}/$g_conf_name/g" $root/$ca_name/ca.conf
    sed -i "s/{{domain_suffix}}/$g_conf_domain_suffix/g" $root/$ca_name/ca.conf
    sed -i "s/{{organization}}/$g_conf_organization/g" $root/$ca_name/ca.conf
}

function build_rsa_ca
{
    ca_dir=$1

    cd $ca_dir

    mkdir private
    mkdir certs
    mkdir db
    touch db/index
    touch db/serial
    touch db/crlnumber
    echo 01 > db/crlnumber

    $g_openssl rand -hex 16 > db/serial

    # gen root ca
    $g_openssl req -new \
                   -config ca.conf \
                   -out ca.csr \
                   -keyout private/ca.pem.key \
                   -passout pass:$conf_passwd

    $g_openssl ca -selfsign \
                  -config ca.conf \
                  -in ca.csr \
                  -out ca.pem.crt \
                  -extensions ca_ext \
                  -passin pass:$conf_passwd \
                  -notext \
                  -batch

    # gen ocsp csr
    $g_openssl req -new \
                   -newkey rsa:2048 \
                   -subj "/C=CN/O=$g_conf_organization/CN=$g_conf_name OCSP Root Responder" \
                   -keyout private/ocsp.pem.key \
                   -out ocsp.csr \
                   -passout pass:$conf_passwd

    # gen ocsp crt
    $g_openssl ca -config ca.conf \
                  -in ocsp.csr \
                  -out ocsp.pem.crt \
                  -extensions ocsp_ext \
                  -days 3650 \
                  -passin pass:$conf_passwd \
                  -notext \
                  -batch
}

function build_rsa_sub_ca
{
    root_ca_dir=$1
    ca_dir=$2

    cd $ca_dir

    mkdir private
    mkdir certs
    mkdir db
    touch db/index
    touch db/serial
    touch db/crlnumber
    echo 01 > db/crlnumber

    $g_openssl rand -hex 16 > db/serial

    # gen sub ca csr
    $g_openssl req -new \
                   -config ca.conf \
                   -out ca.csr \
                   -keyout private/ca.pem.key \
                   -passout pass:$conf_passwd

    # gen sub ca crt
    cd $root_ca_dir
    $g_openssl ca -config ca.conf \
                  -in $ca_dir/ca.csr \
                  -out $ca_dir/ca.pem.crt \
                  -extensions sub_ca_ext \
                  -passin pass:$conf_passwd \
                  -notext \
                  -batch
    cd -

    # gen ocsp csr
    $g_openssl req -new \
                   -newkey rsa:2048 \
                   -subj "/C=CN/O=$g_conf_organization/CN=$g_conf_name OCSP Sub Responder" \
                   -keyout private/ocsp.pem.key \
                   -out ocsp.csr \
                   -passout pass:$conf_passwd

    # gen ocsp crt
    $g_openssl ca -config ca.conf \
                  -in ocsp.csr \
                  -out ocsp.pem.crt \
                  -extensions ocsp_ext \
                  -days 3650 \
                  -passin pass:$conf_passwd \
                  -notext \
                  -batch
}

function build_gm_ca
{
    ca_dir=$1

    cd $ca_dir

    mkdir private
    mkdir certs
    mkdir db
    touch db/index
    touch db/serial
    touch db/crlnumber
    echo 01 > db/crlnumber
    $g_openssl rand -hex 16 > db/serial

    # gen gm root key
    $g_openssl ecparam -genkey \
                       -name SM2 \
                       -out private/ca.pem.key

    # gen gm root csr
    $g_openssl req -config ca.conf \
        -key private/ca.pem.key \
        -new \
        -out ca.csr \
        -passout pass:$conf_passwd

    # gen gm root crt
    $g_openssl x509 -sm3 -req \
        -extfile ca.conf \
        -in ca.csr \
        -extensions ca_ext \
        -signkey private/ca.pem.key \
        -out ca.pem.crt \
        -days 3650 \
        -passin pass:$conf_passwd
}

function build_gm_sub_ca
{
    root_ca_dir=$1
    ca_dir=$2

    cd $ca_dir

    mkdir private
    mkdir certs
    mkdir db
    touch db/index
    touch db/serial
    touch db/crlnumber
    echo 01 > db/crlnumber
    $g_openssl rand -hex 16 > db/serial

    # gen gm sub key
    $g_openssl ecparam -genkey \
                       -name SM2 \
                       -out private/ca.pem.key

    # gen sub ca csr
    $g_openssl req -config ca.conf \
                   -key private/ca.pem.key \
                   -new \
                   -out ca.csr \
                   -passout pass:$conf_passwd

    # gen sub ca crt
    cd $root_ca_dir
    $g_openssl ca -config ca.conf \
                  -in $ca_dir/ca.csr \
                  -out $ca_dir/ca.pem.crt \
                  -extensions sub_ca_ext \
                  -md sm3 \
                  -passin pass:$conf_passwd \
                  -notext \
                  -batch
    cd -

    # gen gm ocsp key
    $g_openssl ecparam -genkey \
                       -name SM2 \
                       -out private/ocsp.pem.key

    # gen gm ocsp csr
    $g_openssl req -new \
        -subj "/C=CN/O=$g_conf_organization/CN=$g_conf_name OCSP GM Sub Responder" \
        -key private/ocsp.pem.key \
        -out ocsp.csr \
        -passout pass:$conf_passwd

    # gen gm ocsp crt
    $g_openssl ca -config ca.conf \
                  -in ocsp.csr \
                  -out ocsp.pem.crt \
                  -extensions ocsp_ext \
                  -days 3650 \
                  -md sm3 \
                  -passin pass:$conf_passwd \
                  -notext \
                  -batch
}

################## Main ##################

# init

[ -d $root ] && rm -rf $root

mkdir $root

d_redirect_to_file $g_log_file

g_ca_names="root-ca sub-ca gm-root-ca gm-sub-ca"

for ca_name in $g_ca_names
do
    init_ca $ca_name $bin_dir/$ca_name.conf
done

# build rsa ca

build_rsa_ca $g_root_ca_dir
build_rsa_sub_ca $g_root_ca_dir $g_sub_ca_dir

# build gm ca

build_gm_ca $g_gm_root_ca_dir
build_gm_sub_ca $g_gm_root_ca_dir $g_gm_sub_ca_dir


# revoke crt
#     $g_openssl ca -config sub-ca.conf -revoke certs/1002.pem.crt -crl_reason unspecified
#
# start ocsp:
#     $g_openssl ocsp -port 9081 -index db/index -rsigner sub-ocsp.pem.crt -rkey private/sub-ocsp.pem.key -CA sub-ca.pem.crt -text
#
# test ocsp
#     $g_openssl ocsp -issuer sub-ca.pem.crt -CAfile root-ca.pem.crt -cert revoke-client-rsa2048.pem.crt -url http://127.0.0.1:9081
#
# gen gm key
#     $g_openssl ecparam -name SM2 -out server-gm.pem.curve
#     $g_openssl genpkey -out server-gm.pem.key -paramfile server-gm.pem.curve
#
# gen key
#     $g_openssl genpkey -out privkey.pem -algorithm RSA -pkeyopt rsa_keygen_bits:2048
#
# gen csr
#    $g_openssl req -new -config csr.conf -key privkey.pem -out priv.csr
#
# gen server crt
#     $g_openssl ca -config sub-ca.conf -in server.csr -out server.pem.crt -extensions server_ext -notext
#
# gen server gm crt
#     $g_openssl ca -config gm-sub-ca.conf -in server.csr -out server.pem.crt -extensions server_gm_ext -md sm3 -notext
#
# gen server gm enc crt
#     $g_openssl ca -config gm-sub-ca.conf -in server-enc.csr -out server-enc.pem.crt -extensions server_gm_enc_ext -md sm3 -notext
#
# gen client crt
#     $g_openssl ca -config sub-ca.conf -days 365 -in priv.csr -out cert.pem -extensions client_ext -notext
#
# gen client gm crt
#     $g_openssl ca -config gm-sub-ca.conf -in client.csr -out client.pem.crt -extensions client_gm_ext -md sm3 -notext
#
# gen client gm enc crt
#     $g_openssl ca -config gm-sub-ca.conf -in client-enc.csr -out client-enc.pem.crt -extensions client_gm_enc_ext -md sm3 -notext
#
# gen crl
#    $g_openssl ca -gencrl -config sub-ca.conf -out sub-ca.pem.crl

# gen p12
#    $g_openssl pkcs12 -export -clcerts -in cert.pem -inkey privkey.pem -out cert.p12
