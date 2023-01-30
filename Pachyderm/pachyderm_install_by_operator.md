# Pachyderm Installation by Operator

You can install a pachyderm operator through operatorhub. This is the most easist part.
This doc explain how to create pachyderm CR and Secret for s3 bucket.

## Ceph

### Pre-requisites
- [Ceph Nano installation](../ceph-nano/ceph-nano-installation-on-openshift.md)

**Secret**
~~~
export CEPH_NS=ceph-nano
export PACHYDERM_NS=pachyderm   
export id=$(oc get secret ceph-nano-credentials -n ${CEPH_NS} -o jsonpath='{ .data.AWS_ACCESS_KEY_ID}'|base64 -d)
export secret=$(oc get secret ceph-nano-credentials -n ${CEPH_NS} -o jsonpath='{ .data.AWS_SECRET_ACCESS_KEY}'|base64 -d)
export endpoint=$(oc get svc ceph-nano-0 -n ${CEPH_NS} -o jsonpath='{ .spec.clusterIP }' )

oc new-project ${PACHYDERM_NS}
oc create secret generic pachyderm-ceph-secret -n ${PACHYDERM_NS}\
--from-literal=access-id=${id}  \
--from-literal=access-secret=${secret} \
--from-literal=custom-endpoint=http://${endpoint} \
--from-literal=region=us-east-2 \
--from-literal=bucket=pachyderm
~~~

**Pachyderm CR**
~~~
echo "
kind: Pachyderm
apiVersion: aiml.pachyderm.com/v1beta1
metadata:
  name: pachyderm-ceph
spec:
  console:
    disable: true
  pachd:
    metrics:
      disable: false
    storage:
      amazon:
        credentialSecretName: pachyderm-ceph-secret
      backend: AMAZON
"|oc create -f -n ${PACHYDERM_NS} -
~~~


## MinIO
### Pre-requisites
- [MinIO installation](../minio/minio_installation.md)

**Secret**
~~~
export MINIO_NS=minio-operator
export PACHYDERM_NS=pachyderm  

oc create secret generic pachyderm-minio-secret -n ${PACHYDERM_NS} \
--from-literal=access-id=XXX  \
--from-literal=access-secret=XXX \
--from-literal=custom-endpoint=minio.minio-tenant-1.svc.cluster.local:443
--from-literal=region=us-east-2 \
--from-literal=bucket=pachyderm
~~~

**Pachyderm CR**
~~~
echo "
kind: Pachyderm
apiVersion: aiml.pachyderm.com/v1beta1
metadata:
  name: pachyderm-sample
spec:
  console:
    disable: true
  pachd:
    metrics:
      disable: false
    storage:
      amazon:
        credentialSecretName: pachyderm-minio-secret
      backend: AMAZON
"|oc create -f -
~~~

## AWS S3
### Pre-requisites
- Create a S3 Bucket on AWS
  
**Secret**
~~~
oc create secret generic pachyderm-aws-secret \
--from-literal=id=XXX  \
--from-literal=secret=XXX \
--from-literal=region=us-east-2 \
--from-literal=bucket=pachyderm
~~~
**Pachyderm CR**
~~~
echo "
kind: Pachyderm
apiVersion: aiml.pachyderm.com/v1beta1
metadata:
  name: pachyderm-sample
spec:
  console:
    disable: true
  pachd:
    metrics:
      disable: false
    storage:
      amazon:
        credentialSecretName: pachyderm-aws-secret
      backend: AMAZON
"|oc create -f -
~~~
