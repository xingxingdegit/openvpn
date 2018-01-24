# openvpn

conf 目录存储了openssl配置文件， 是脚本使用的。  还有openvpn.conf client.conf 是openvpn的服务端与客户端的配置文件例子。


<pre>
./openssl.sh init &lt;name&gt;         # ./openssl.sh init ca.atest.pub
./openssl.sh dh                  # ./openssl.sh dh
./openssl.sh build &lt;name&gt;        # ./openssl.sh build xiaomei    openvpn客户端所用证书。
./openssl.sh build server        # 跟上面一行一样， 只是生成一个证书， openvpn用来做为server证书。
./openssl.sh revoke &lt;name&gt;       # 注销证书
./openssl.sh revoke &lt;name&gt; -f    # 注销证书，上面注销失败的话。

openvpn conf/openvpn.conf        #  启动openvpn。   这里只是一个例子，大家可以相应修改里面的证书与key还有dh文件和log所对应的文件与目录。

相关证书存储在CA/certs里面。
</pre>
