# Operator/Bundle build guide

## Pre-requisites
- Download [this operatorsdk.sh](./operatorsdk.sh) and put it into openshift-operator repo
- Update the operatorsdk.sh such as quay.io, version
- Try ./operatorsdk.sh --help


## Operator 
~~~
operatorsdk.sh op build
operatorsdk.sh op push
~~~

## Bundle
Update bundle information such as version in /bundle folder
~~~
operatorsdk.sh bundle build
operatorsdk.sh bundle push
~~~

## Index
~~~
operatorsdk.sh index build --new
operatorsdk.sh index push 
operatorsdk.sh index deploy
~~~

When you finish testing, then remove Pachyderm Cr --> Pachyderm Operator --> Pachyderm Catalog Source

Remove Pachyderm catalogsource
~~~
operatorsdk.sh index deploy
~~~
