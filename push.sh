#!/bin/bash
BK_REPO=../blog_backup
BLOG_DIR=$(pwd)
cp -rv ./public ${BK_REPO}/
cp -rv ./source ${BK_REPO}/
cp -v ./_config.yml ${BK_REPO}/
cp -v ./node_modules/hexo-theme-butterfly/_config.yml  ${BK_REPO}/_config-butterfly.yml
cp -v ./package*.json ${BK_REPO}/
cp -rv ./push.sh ${BK_REPO}/
cd ${BK_REPO}
git add .
git commit -m "site update $(date)"
git push
cd ${BLOG_DIR}
./node_modules/hexo/bin/hexo g
./node_modules/hexo/bin/hexo d
