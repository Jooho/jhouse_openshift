* Deploy ODH operators
~~~
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/opendatahub-operator.openshift-operators: ""
  name: opendatahub-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: opendatahub-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: opendatahub-operator.v1.1.1
EOF
~~~

* Create KfDef
~~~
oc new-project opendatahub
  
cat << EOF | oc apply -f -  
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  name: opendatahub
  namespace: opendatahub
spec:
  applications:
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: odh-common
      name: odh-common
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: odh-dashboard
      name: odh-dashboard
    - kustomizeConfig:
        parameters:
          - name: s3_endpoint_url
            value: s3.odh.com
        repoRef:
          name: manifests
          path: jupyterhub/jupyterhub
      name: jupyterhub
    - kustomizeConfig:
        overlays:
          - additional
        repoRef:
          name: manifests
          path: jupyterhub/notebook-images
      name: notebook-images
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: ceph/object-storage/scc
      name: ceph-nano-scc
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: ceph/object-storage/nano
      name: ceph-nano
    - kustomizeConfig:
        parameters:
          - name: namespace
            value: openshift-operators       
          - name: pachyderm_version
            value: 0.0.8
        repoRef:
          name: manifests
          path: odhpachyderm/cluster
      name: odhpachyderm
  repos:
    - name: kf-manifests
      uri: 'https://github.com/opendatahub-io/manifests/tarball/v1.3-openshift'
    - name: manifests
      uri: 'https://github.com/Jason4849/odh-manifests/tarball/pachyderm'   
EOF
~~~

* Create a bucket
  * console
  ~~~
  oc port-forward pod/ceph-nano-0 5001 8000
  ~~~
  * boto
  ~~~
  oc rsh pod/ceph-nano-0 

  export access_key=$(radosgw-admin user info --uid=cn |jq .keys[0].access_key -r)
  export secret_key=$(radosgw-admin user info --uid=cn |jq .keys[0].secret_key -r)

  cat << EOF > s3test.py
  import boto.s3.connection

  access_key = '${access_key}'
  secret_key = '${secret_key}'
  conn = boto.connect_s3(
          aws_access_key_id=access_key,
          aws_secret_access_key=secret_key,
          host='127.0.0.1', port=8000,
          is_secure=False, calling_format=boto.s3.connection.OrdinaryCallingFormat(),
        )

  bucket = conn.create_bucket('pachyderm-ceph')
  for bucket in conn.get_all_buckets():
      print "{name} {created}".format(
          name=bucket.name,
          created=bucket.creation_date,
      )
      
  EOF

  yum install python-boto -y
  python s3test.py
  ~~~

* Create a Pachyderm Secret
~~~
export CEPH_NS=opendatahub
export PACHYDERM_NS=opendatahub
export id=$(oc get secret ceph-nano-credentials -n ${CEPH_NS} -o jsonpath='{ .data.AWS_ACCESS_KEY_ID}'|base64 -d)
export secret=$(oc get secret ceph-nano-credentials -n ${CEPH_NS} -o jsonpath='{ .data.AWS_SECRET_ACCESS_KEY}'|base64 -d)
export endpoint=$(oc get svc ceph-nano-0 -n ${CEPH_NS} -o jsonpath='{ .spec.clusterIP }' )


oc create secret generic pachyderm-ceph-secret -n ${PACHYDERM_NS} \
--from-literal=access-id=${id}  \
--from-literal=access-secret=${secret} \
--from-literal=custom-endpoint=http://${endpoint} \
--from-literal=region=us-east-2 \
--from-literal=bucket=pachyderm-ceph
~~~

* Create Pachyderm CR
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
"|oc apply -n ${PACHYDERM_NS} -f -
~~~

* Spwan Jupyter notebook
* Clone github
~~~
https://github.com/Jooho/pachyderm-operator-manifests.git
~~~

* Open the OpenCV notebook
~~~
pachyderm-operator-manifests/notebooks/pachyderm-opencv.ipynb
~~~

* Update pachd address
~~~
pachd_address: pachd.opendatahub.svc.cluster.local:30650
~~~
