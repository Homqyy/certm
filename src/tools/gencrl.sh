#!/bin/bash

tool_dir=`dirname $0`

. $tool_dir/../settings.conf

cd $g_sub_ca_dir
$g_openssl ca -gencrl -config sub-ca.conf -out sub-ca.pem.crl -passin pass:root
cd -

cd $g_gm_sub_ca_dir
$g_openssl ca -gencrl -config gm-sub-ca.conf -out gm-sub-ca.pem.crl -md sm3 -passin pass:root
cd -
