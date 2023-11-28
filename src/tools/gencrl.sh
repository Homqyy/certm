#!/bin/bash

tool_dir=`dirname $0`

source $CERTM_CONFIG_FILE

ca_dir=$CERTM_OUTPUT_DIR/ca

cd $CERTM_SUB_CA_DIR
$CERTM_OPENSSL ca -gencrl -config ca.conf -out $ca_dir/sub-ca.pem.crl -passin pass:root
cd -

cd $CERTM_GM_SUB_CA_DIR
$CERTM_OPENSSL ca -gencrl -config ca.conf -out $ca_dir/gm-sub-ca.pem.crl -md sm3 -passin pass:root
cd -
