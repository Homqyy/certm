#!/bin/bash

tool_dir=`dirname $0`

source $CERTM_CF_SETTINGS

ca_dir=$CERTM_PATH_OUTPUT_DIR/ca

[ -d $ca_dir ] || mkdir $ca_dir

cd $CERTM_PATH_SUB_CA_DIR
$CERTM_BIN_OPENSSL ca -gencrl -config ca.conf -out $ca_dir/sub-ca.pem.crl -passin pass:root
cd -

cd $CERTM_PATH_GM_SUB_CA_DIR
$CERTM_BIN_OPENSSL ca -gencrl -config ca.conf -out $ca_dir/gm-sub-ca.pem.crl -md sm3 -passin pass:root
cd -
