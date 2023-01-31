# Ceph Nano
Ceph is an open-source software storage platform, implements object storage on a single distributed computer cluster, and provides 3-in-1 interfaces for object-, block- and file-level storage. 

In a Kubernetes environment, Rook enables deployment of Ceph but it is not trivial process for just deployment of ceph.

Therefore, Ceph Nano come in and it provides a easy deployment way like 1 click. Using `cn` [command](https://github.com/ceph/cn), you can deploy ceph on docker. However, if you want to deploy ceph on OpenShift, [cn-core](https://github.com/ceph/cn-core) is easier because it provide container image.

This doc will provide full commands to deploy ceph-cn on openshift

~~~
export NAMESPACE=ceph-nano

oc new-project ${NAMESPACE}

cd /tmp

git clone https://github.com/Jason4849/odh-manifests/tree/ceph_dashboard

cd ceph

curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.4.1/kustomize_v4.4.1_linux_amd64.tar.gz | tar xz

cd scc/base/ ;./kustomize edit set namespace ${NAMESPACE} ; cd ../../

./kustomize build scc/base|oc create -f -

./kustomize build nano/base|oc create -f -

oc port-forward pod/ceph-nano-0 5001 8000
~~~

Try to create a sample bucket using boto.
~~~
oc rsh pod/ceph-nano-0

export access_key=$(radosgw-admin user info --uid=cn |jq .keys[0].access_key -r)
export secret_key=$(radosgw-admin user info --uid=cn |jq .keys[0].secret_key -r)

cat << EOF > python.py
import boto.s3.connection

access_key = '${access_key}'
secret_key = '${secret_key}'
conn = boto.connect_s3(
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        host='127.0.0.1', port=8000,
        is_secure=False, calling_format=boto.s3.connection.OrdinaryCallingFormat(),
       )

bucket = conn.create_bucket('my-new-bucket')
for bucket in conn.get_all_buckets():
    print "{name} {created}".format(
        name=bucket.name,
        created=bucket.creation_date,
    )
    
EOF

yum install python-boto -y
python s3test.py
~~~

If you see this message, you confirm that your ceph bucket is working successfully.
~~~
my-new-bucket 2021-11-25T21:34:20.225Z
~~~
Then, access to a ceph console and create/manage S3 buckets.
