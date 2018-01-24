#!/bin/bash

openssl_conf=conf/openssl.cnf

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

export CA_DIR="$(pwd)/CA"                   # CA目录
export KEY_COUNTRY="CN"                     # 国家
export KEY_PROVINCE="BJ"                    # 省市
export KEY_CITY="BJ"                        # 城市
export KEY_ORG="ATEST"                      # 组织
export KEY_OUNAME="op"                      # 部门名称
export KEY_EMAIL="op@atest.pub"             # 邮件
export KEY_COMMONNAME="vpnatest"            # 主机名,没用，在下面还会指定

if [ $# -eq 0 ];then
    echo "Usage: $0 {init <name> | build <name> } | revoke <name> | reinit | dh}"
fi

env_pre () {
    if [ ! -d $CA_DIR ]; then
        mkdir -p $CA_DIR || exit 1
    fi
    
    mkdir $CA_DIR/certs && \
    mkdir $CA_DIR/newcerts && \
    mkdir $CA_DIR/private && \
    mkdir $CA_DIR/crl && \
    touch $CA_DIR/index.txt && \
    echo 00 > $CA_DIR/serial && \
    echo 00 > $CA_DIR/crlnumber
    if [ $? -eq 0 ];then
        return 0
    else
        echo -e "\033[31menv create failure\033[0m"
        return 1
    fi
}

ca_init () {
    env_pre && \
    (umask 077;openssl genrsa -out $CA_DIR/private/cakey.pem 4096) && \
    openssl req -config $openssl_conf -new -x509 -sha256 -key $CA_DIR/private/cakey.pem -out $CA_DIR/cacert.pem -days 3650 && \
    openssl ca -config $openssl_conf -gencrl -out $CA_DIR/crl.pem && \
    echo -e "\033[32mcreate ca cert is successful\033[0m" || echo -e "\033[31mcreate ca cert is failure\033[0m"
}

rebuild_ca () {
    echo -e "\033[32m'rm -rf CA' ,and, 'init <name>' \033[0m"
}

build_user () {
    store_path=$CA_DIR/certs/$1
    mkdir -p $store_path && \
    (umask 077;openssl genrsa -out $store_path/$1.key 2048) && \
    openssl req -config $openssl_conf -new -key $store_path/$1.key -out $store_path/$1.csr && \
    openssl ca -config $openssl_conf -md sha256 -in $store_path/$1.csr -out $store_path/$1.crt -days 3650 && \
    rm -f $store_path/$1.csr && \
    echo -e "\033[32mcreate $1 cert is successful\033[0m" || echo -e "\033[31mcreate $1 cert is failure\033[0m" && \
    cat $CA_DIR/cacert.pem $CA_DIR/crl.pem > $CA_DIR/revoke-test.pem && \
    openssl verify -CAfile $CA_DIR/revoke-test.pem -crl_check $store_path/$1.crt
}


revoke_user () {
    if [ "$2" != "-f" ];then
        store_path=$CA_DIR/certs/$1
        openssl ca -config $openssl_conf -revoke $store_path/$1.crt && \
        openssl ca -config $openssl_conf -gencrl -out $CA_DIR/crl.pem && \
        cat $CA_DIR/cacert.pem $CA_DIR/crl.pem > $CA_DIR/revoke-test.pem && \
        openssl verify -CAfile $CA_DIR/revoke-test.pem -crl_check $store_path/$1.crt

    else

        will_subject="subject= /C=$KEY_COUNTRY/ST=$KEY_PROVINCE/O=$KEY_ORG/OU=$KEY_OUNAME/CN=$1/emailAddress=$KEY_EMAIL"
        for pem in $CA_DIR/newcerts/*;do
            pem_subject=`openssl x509 -in $pem -noout -subject`

            if [ "$pem_subject" == "$will_subject" ];then
                openssl ca -config $openssl_conf -revoke $pem && \
                openssl ca -config $openssl_conf -gencrl -out $CA_DIR/crl.pem
                cat $CA_DIR/cacert.pem $CA_DIR/crl.pem > $CA_DIR/revoke-test.pem && \
                openssl verify -CAfile $CA_DIR/revoke-test.pem -crl_check $pem
            fi
        done
    fi

    if [ $? -eq 2 ];then
        echo -e "\033[32mrevoke $1 cert is successful\033[0m"
    else
        echo -e "\033[31mrevoke $1 cert is failure\033[0m"
    fi

}

build_dh () {
    openssl dhparam -outform pem -out $CA_DIR/dh1024.pem 1024 && \
    echo -e "\033[32mcreate dh pem is successful\033[0m" || \
    echo -e "\033[31mcreate dh pem is failure\033[0m"
}
 

case $1 in
    init)
        if [ -n "$2" ];then
            export KEY_COMMONNAME=$2
        fi
            ca_init ;;

    reinit)
        rebuild_ca ;;

    build)
        if [ -n "$2" ];then
            export KEY_COMMONNAME=$2
            build_user $2
        else
            echo "Usage: $0 {init <name> | build <name> } | revoke <name> | reinit | dh}"
        fi
                ;;

    revoke)
        if [ -n "$2" ];then
            revoke_user $2 $3
        else
            echo "Usage: $0 {init <name> | build <name> } | revoke <name> | reinit | dh}"
        fi
                ;;

    dh)
        build_dh  ;;
        
esac

