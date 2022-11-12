#!/bin/bash

set -e

MYIP="$1"

if [[ "${MYIP}" = "" ]]; then
    echo "Usage: ./gencert.sh {IP}"
    exit 1
fi

generate_rootca() {
    # Generate Root CA key:
    if [ ! -f "rootca.key" ]; then
        echo ""
        echo "Generate Root CA key..."
        openssl genrsa -out rootca.key 4096
    fi

    # Generate Root CA csr:
    if [ ! -f "rootca.csr" ]; then
        echo ""
        echo "Generate Root CA csr..."
        openssl req --config openssl.cnf \
            -new -key rootca.key \
            -out rootca.csr -sha256
    fi

    # Generate Root CA ext:
    if [ ! -f "rootca.ext" ]; then
        echo ""
        echo "Generate Root CA ext..."
        cat <<EOF >rootca.ext
basicConstraints=critical,CA:TRUE
nsComment = "This Root certificate was generated by NoBody"
keyUsage=critical, keyCertSign
subjectKeyIdentifier=hash
EOF
    fi

    # Generate Root CA certificate:
    if [ ! -f "rootca.crt" ]; then
        echo ""
        echo "Generate Root CA certificate..."
        openssl x509 -req \
            -in rootca.csr \
            -signkey rootca.key \
            -out rootca.crt \
            -days 36500 \
            -extfile rootca.ext
    fi
}

generate_cert(){
    if [ ! -f "rootca.crt" ]; then
        generate_rootca
    fi

    # Generate Server key:
    if [ ! -f "server.key" ]; then
        echo ""
        echo "Generate Server key..."
        openssl genrsa -out server.key 4096
    fi

    # Generate Server csr:
    echo ""
    echo "Generate Server csr..."
    openssl req --config openssl.cnf -new \
        -key server.key \
        -out server.scr -sha256
    

    # Generate Server ext:
    echo ""
    echo "Generate Server ext..."
    cat <<EOF >server.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
IP.1 = $MYIP
EOF

    # Generate Server certificate:
    echo ""
    echo "Generate Server certificate..."
    openssl x509 -req \
        -in server.scr \
        -CA rootca.crt \
        -CAkey rootca.key \
        -out server.crt \
        -CAcreateserial \
        -days 36500 \
        -extfile server.ext
}

generate_cert