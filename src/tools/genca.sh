#!/bin/bash

tool_dir=`dirname $0`

source $CERTM_CF_SETTINGS

ca_dir=$CERTM_PATH_OUTPUT_DIR/ca

[ -d $ca_dir ] || mkdir $ca_dir

cat $CERTM_PATH_GM_SUB_CA_DIR/ca.pem.crt > $ca_dir/ca-chain-gm.pem.crt
cat $CERTM_PATH_GM_ROOT_CA_DIR/ca.pem.crt >> $ca_dir/ca-chain-gm.pem.crt

cat $CERTM_PATH_GM_ROOT_CA_DIR/ca.pem.crt > $ca_dir/ca-gm.pem.crt

cat $CERTM_PATH_SUB_CA_DIR/ca.pem.crt > $ca_dir/ca-chain.pem.crt
cat $CERTM_PATH_ROOT_CA_DIR/ca.pem.crt >> $ca_dir/ca-chain.pem.crt

cat $CERTM_PATH_ROOT_CA_DIR/ca.pem.crt > $ca_dir/ca.pem.crt

cat $CERTM_PATH_ROOT_CA_DIR/ca.pem.crt > $ca_dir/ca-all.pem.crt
cat $CERTM_PATH_GM_ROOT_CA_DIR/ca.pem.crt >> $ca_dir/ca-all.pem.crt
