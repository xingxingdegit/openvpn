#!/bin/bash
#conf 目录存储了openssl配置文件，是脚本使用的。还有openvpn.conf client.conf 是openvpn的服务端与客户端的配置文件例子。
#openvpn conf/openvpn.conf        # 启动openvpn。这里只是一个例子，大家可以相应修改里面的证书与key还有dh文件和log所对应的文件与目录。
#相关证书存储在CA/certs里面。
#./openssl.sh init <name>         # ./openssl.sh init ca.atest.pub
#./openssl.sh dh                  # ./openssl.sh dh
#./openssl.sh build <name>        # ./openssl.sh build xiaomei    openvpn客户端所用证书。
#./openssl.sh build <server>      # 跟上面一行一样， 只是生成一个证书，也可以用别的名子，openvpn用来做为server证书。
#./openssl.sh revoke <name>       # 注销证书
#./openssl.sh revoke <name> -f    # 注销证书，上面注销失败的话。


openssl_conf=conf/openssl.cnf

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

export CA_DIR="$(pwd)/CA"                   # CA目录
export KEY_COUNTRY="CN"                     # 国家
export KEY_PROVINCE="BJ"                    # 省市
export KEY_CITY="BJ"                        # 城市
export KEY_ORG="qfpay.com"                      # 组织
export KEY_OUNAME="op"                      # 部门名称
export KEY_EMAIL="op@qfpay.com"             # 邮件
export KEY_COMMONNAME="vpnserver"            # 主机名,没用，在下面还会指定

# CA证书有效期，crl证书有效期，用户证书有效期
CA_expire=3650
CRL_expire=3650
User_expire=3650

if [ $# -eq 0 ];then
    echo "Usage: $0 {init <name> | build <name> [san]} | revoke <name> | reinit | dh}"
    echo "san is Subject Alternative Name"
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
    openssl req -config $openssl_conf -new -x509 -sha256 -key $CA_DIR/private/cakey.pem -out $CA_DIR/cacert.pem -days $CA_expire && \
    openssl ca -config $openssl_conf -gencrl -out $CA_DIR/crl.pem -crldays $CRL_expire&& \
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
    if [ "$2" == "san" ];then
        openssl ca -config $openssl_conf -extensions v3_req -md sha256 -in $store_path/$1.csr -out $store_path/$1.crt -days $User_expire
    else
        openssl ca -config $openssl_conf -md sha256 -in $store_path/$1.csr -out $store_path/$1.crt -days $User_expire
    fi && \
    rm -f $store_path/$1.csr && \
    echo -e "\033[32mcreate $1 cert is successful\033[0m" || echo -e "\033[31mcreate $1 cert is failure\033[0m" && \
    cat $CA_DIR/cacert.pem $CA_DIR/crl.pem > $CA_DIR/revoke-test.pem && \
    openssl verify -CAfile $CA_DIR/revoke-test.pem -crl_check $store_path/$1.crt

    userdir=usertmp/$1
    mkdir -p $userdir
    cp $store_path/$1.crt $userdir/
    cp $store_path/$1.key $userdir/
    cp $CA_DIR/cacert.pem $userdir/
    cp conf/client.conf $userdir/
    sed -i "s/xiaoli/$1/g" $userdir/client.conf


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
    openssl dhparam -outform pem -out $CA_DIR/dh2048.pem 2048 && \
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

