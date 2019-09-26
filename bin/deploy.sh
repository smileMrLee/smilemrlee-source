#!/usr/bin/env bash
cd  /Users/rongli/workspace/mkdoc/smileMrLee
mkdocs build
cp -rf /Users/rongli/workspace/mkdoc/smileMrLee/site/ /Users/rongli/workspace/github/smileMrLee.github.io/ 
cd /Users/rongli/workspace/github/smileMrLee.github.io
git add .
git commit -m "发布提交"
git push
echo "发布github完成"
