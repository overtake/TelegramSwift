#/bin/sh
#set -x
#set -e

export PATH="$PATH:$HOME/.credentials"


cd ..

if [ ! -d "./deploy" ]; then
    git clone $deploy_repository deploy
else
    git --work-tree=./deploy --git-dir=./deploy/.git pull origin master
fi

