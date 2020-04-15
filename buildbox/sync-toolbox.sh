#/bin/sh
set -x
set -e

export PATH="$PATH:$HOME/.credentials"
source variables.sh
MAIN_REPOSITORY=$PWD
cd ..
if [ ! -d "./deploy" ]; then
    mkdir -p ./deploy
    git clone "$deploy_repository" deploy
else
    cd ./deploy
    git reset --hard
    git pull origin master
    cd ..
fi
