# Tools

**yq(4.0+)**
~~~
YQ_VERSION=4.30.8
wget https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64
chmod 777 yq_linux_amd64 
sudo mv yq_linux_amd64 /usr/local/bin/yq
~~~

**jq(1.6)**
~~~
JQ_VERSION=1.6
wget https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64
chmod 777 jq_linux64
sudo mv jq_linux64 /usr/local/bin/jq
~~~

**grpcurl(1.8.7)**
~~~
GRPCURL_VERSION=1.8.7
curl -L https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION}_linux_x86_64.tar.gz | tar xz

chmod 777 grpcurl
sudo mv grpcurl /usr/local/bin/grpcurl
~~~

**virtualenv**

- Refer [Guide](./Virtualenv.md)