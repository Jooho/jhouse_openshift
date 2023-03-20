#!/bin/bash
export DEMO_HOME=/tmp/modelmesh

mkdir -p $DEMO_HOME
cp -R ./* ${DEMO_HOME}/.
# Clone jhouse repository
# git clone https://github.com/Jooho/jhouse_openshift.git
ln -s /home/jooho/dev/git/jhouse_openshift ${DEMO_HOME}/jhouse_openshift

echo
echo "FOR DEMO, move your foler with following command"
echo "cd ${DEMO_HOME}"
