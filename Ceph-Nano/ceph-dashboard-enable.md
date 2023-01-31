# Ceph Mgr Dashboard

After you have ceph nano, you already have a console(S3 web client-SREE) but if you also enable Ceph Mgr dashboard.

This commands will make it happen.

~~~
oc patch statefulset/ceph-nano \
 -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports/-", "value":{"name":"dashboard","containerPort":8080,"protocol":"TCP"}}]' \
 --type='json'

oc create service clusterip ceph --tcp=80:8080
oc expose svc/ceph --name=ceph-dashboard 

oc rsh pod/ceph-nano-0


ceph config set mgr mgr/dashboard/ssl false
ceph config set mgr mgr/dashboard/server_addr 0.0.0.0
ceph config set mgr mgr/dashboard/server_port 8080
ceph mgr module enable dashboard

radosgw-admin user modify --uid=cn --system

export access_key=$(radosgw-admin user info --uid=cn |jq .keys[0].access_key -r)
export secret_key=$(radosgw-admin user info --uid=cn |jq .keys[0].secret_key -r)

ceph dashboard set-rgw-api-access-key "${access_key}"
ceph dashboard set-rgw-api-secret-key "${secret_key}"
ceph dashboard set-rgw-api-host 127.0.0.1
ceph dashboard set-rgw-api-port 8000
ceph dashboard set-rgw-api-scheme http
ceph dashboard set-rgw-api-user-id cn

ceph dashboard ac-user-create nano nano administrator

ceph mgr module disable dashboard
ceph mgr module enable dashboard
~~~