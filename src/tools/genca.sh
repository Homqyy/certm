#!/bin/bash

tool_dir=`dirname $0`

. $tool_dir/../settings.conf

ca_dir=$g_root_dir/ca

[ -d $ca_dir ] || mkdir $ca_dir

cat $g_gm_sub_ca_dir/gm-sub-ca.pem.crt > $ca_dir/ca-chain-gm.pem.crt
cat $g_gm_root_ca_dir/gm-root-ca.pem.crt >> $ca_dir/ca-chain-gm.pem.crt

cat $g_gm_root_ca_dir/gm-root-ca.pem.crt > $ca_dir/ca-gm.pem.crt

cat $g_sub_ca_dir/sub-ca.pem.crt > $ca_dir/ca-chain.pem.crt
cat $g_root_ca_dir/root-ca.pem.crt >> $ca_dir/ca-chain.pem.crt

cat $g_root_ca_dir/root-ca.pem.crt > $ca_dir/ca.pem.crt

cat $g_root_ca_dir/root-ca.pem.crt > $ca_dir/ca-all.pem.crt
cat $g_gm_root_ca_dir/gm-root-ca.pem.crt >> $ca_dir/ca-all.pem.crt
