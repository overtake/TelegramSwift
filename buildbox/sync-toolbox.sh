#/bin/sh
#set -x
#set -e

export PATH="$PATH:$HOME/.credentials"
source variables.sh

cd ..
rm -rf "./deploy"
git clone "$deploy_repository" deploy

