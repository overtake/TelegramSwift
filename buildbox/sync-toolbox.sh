#/bin/sh
set -x
set -e

export PATH="$PATH:$HOME/.credentials"
source variables.sh

cd ..
if [ ! -d "./deploy" ]; then
    mkdir -p ./deploy
    git clone "$deploy_repository" deploy
else
    cd ./deploy
    git reset --hard
    git pull origin master
fi

