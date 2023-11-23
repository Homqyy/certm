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

bin_dir=$( cd `dirname $0`; pwd )

. $bin_dir/settings.conf

root=$g_root_dir

conf_passwd=root

# init

g_ca_names="root-ca sub-ca gm-root-ca gm-sub-ca"

for ca_name in $g_ca_names
do
    rm -rf $root/$ca_name
    mkdir $root/$ca_name
    cp $bin_dir/$ca_name.conf $root/$ca_name/$ca_name.conf
    sed -i "s/{{name}}/$conf_name/g" $root/$ca_name/$ca_name.conf
    sed -i "s/{{domain_suffix}}/$conf_domain_suffix/g" $root/$ca_name/$ca_name.conf
    sed -i "s/{{organization}}/$conf_organization/g" $root/$ca_name/$ca_name.conf
done

rm -rf $root/clients
rm -rf  $root/servers
mkdir $root/clients
mkdir $root/servers

cd $root/root-ca

mkdir private
mkdir certs
mkdir db
touch db/index
touch db/serial
touch db/crlnumber
echo 01 > db/crlnumber
$g_openssl rand -hex 16 > db/serial

# gen root ca
$g_openssl req -new -config root-ca.conf -out root-ca.csr -keyout private/root-ca.pem.key -passout pass:$conf_passwd
$g_openssl ca -selfsign -config root-ca.conf -in root-ca.csr -out root-ca.pem.crt -extensions ca_ext -notext -passin pass:$conf_passwd -batch

# gen ocsp csr
$g_openssl req -new -newkey rsa:2048 -subj "/C=CN/O=$conf_organization/CN=$conf_name OCSP Root Responder" -keyout private/root-ocsp.pem.key -out root-ocsp.csr -passout pass:$conf_passwd

# gen ocsp crt
$g_openssl ca -config root-ca.conf -in root-ocsp.csr -out root-ocsp.pem.crt -extensions ocsp_ext -days 3650 -notext -passin pass:$conf_passwd -batch

cd $root/sub-ca

mkdir private
mkdir certs
mkdir db
touch db/index
touch db/serial
touch db/crlnumber
echo 01 > db/crlnumber
$g_openssl rand -hex 16 > db/serial

# gen sub ca csr
$g_openssl req -new -config sub-ca.conf -out sub-ca.csr -keyout private/sub-ca.pem.key -passout pass:$conf_passwd

# gen sub ca crt
cd $root/root-ca
$g_openssl ca -config root-ca.conf -in ../sub-ca/sub-ca.csr -out ../sub-ca/sub-ca.pem.crt -extensions sub_ca_ext -notext -passin pass:$conf_passwd -batch
cd $root/sub-ca

# gen ocsp csr
$g_openssl req -new -newkey rsa:2048 -subj "/C=CN/O=$conf_organization/CN=$conf_name OCSP Sub Responder" -keyout private/sub-ocsp.pem.key -out sub-ocsp.csr -passout pass:$conf_passwd

# gen ocsp crt
$g_openssl ca -config sub-ca.conf -in sub-ocsp.csr -out sub-ocsp.pem.crt -extensions ocsp_ext -days 3650 -notext -passin pass:$conf_passwd -batch

cd $root/gm-root-ca

mkdir private
mkdir certs
mkdir db
touch db/index
touch db/serial
touch db/crlnumber
echo 01 > db/crlnumber
$g_openssl rand -hex 16 > db/serial

# gen gm root key
$g_openssl ecparam -genkey -name SM2 -out private/gm-root-ca.pem.key

# gen gm root csr
$g_openssl req -config gm-root-ca.conf \
	-key private/gm-root-ca.pem.key \
	-new \
	-out gm-root-ca.csr \
	-passout pass:$conf_passwd

# gen gm root crt
$g_openssl x509 -sm3 -req \
	-extfile gm-root-ca.conf \
	-in gm-root-ca.csr \
	-extensions ca_ext \
	-signkey private/gm-root-ca.pem.key \
	-out gm-root-ca.pem.crt \
    -days 3650 \
	-passin pass:$conf_passwd

cd $root/gm-sub-ca

mkdir private
mkdir certs
mkdir db
touch db/index
touch db/serial
touch db/crlnumber
echo 01 > db/crlnumber
$g_openssl rand -hex 16 > db/serial

# gen gm sub key
$g_openssl ecparam -genkey -name SM2 -out private/gm-sub-ca.pem.key

# gen sub ca csr
$g_openssl req -config gm-sub-ca.conf -key private/gm-sub-ca.pem.key -new -out gm-sub-ca.csr -passout pass:$conf_passwd

# gen sub ca crt
cd $root/gm-root-ca
$g_openssl ca -config gm-root-ca.conf -in ../gm-sub-ca/gm-sub-ca.csr -out ../gm-sub-ca/gm-sub-ca.pem.crt -extensions sub_ca_ext -md sm3 -notext -passin pass:$conf_passwd -batch
cd $root/gm-sub-ca

# gen gm ocsp key
$g_openssl ecparam -genkey -name SM2 -out private/gm-sub-ocsp.pem.key

# gen gm ocsp csr
$g_openssl req -new \
	-subj "/C=CN/O=$conf_organization/CN=$conf_name OCSP GM Sub Responder" \
	-key private/gm-sub-ocsp.pem.key \
	-out gm-sub-ocsp.csr \
	-passout pass:$conf_passwd

# gen gm ocsp crt
$g_openssl ca -config gm-sub-ca.conf -in gm-sub-ocsp.csr -out gm-sub-ocsp.pem.crt -extensions ocsp_ext -days 3650 -md sm3 -notext -passin pass:$conf_passwd -batch


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
