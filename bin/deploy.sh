#!/usr/bin/env bash
cd  /Users/lirong/workspace/github/smilemrlee-source
mkdocs build
cp -rf /Users/lirong/workspace/github/smilemrlee-source/site/ /Users/lirong/workspace/github/smileMrLee.github.io/ 
cd /Users/lirong/workspace/github/smileMrLee.github.io
git add .
git commit -m "发布提交"
git push
echo "发布github完成"
