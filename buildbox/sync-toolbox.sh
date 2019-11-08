#/bin/sh
#set -x
#set -e

export PATH="$PATH:$HOME/.credentials"
source variables.sh

cd ..
chmod -R +w,g=rw,o-rw ./deploy
if [ ! -d "./deploy" ]; then
    git clone "$deploy_repository" deploy
else
    git reset --hard --git-dir=./deploy/.git
    git --work-tree=./deploy --git-dir=./deploy/.git pull origin master
fi

