oc get secret test  -o template='{{range $k,$v := .data}}export {{printf "%s=" $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}' | bash -


oc get secret test -ojson | jq '.data'
{
  "AWS_ACCESS_KEY_ID": "QWNjZXNzIEtleSBJRA==",
  "AWS_DEFAULT_BUCKET": "RGVmYXVsdCBCdWNrZXQ=",
  "AWS_DEFAULT_REGION": "cmVnaW9u",
  "AWS_S3_ENDPOINT": "ZW5kcG9pbnR1cmw=",
  "AWS_SECRET_ACCESS_KEY": "U2VjcmV0IEFjY2VzcyBLZXk=",
  "type": "czM="
}
Sean Pryor오후 2:35
oc get secret test -ojson | jq '.data | map_values(@base64d)'
Sean Pryor오후 2:38
oc get secret test -ojson | jq -r '.data | map_values(@base64d) | to_entries[] | [.key,.value] | join("=")'
