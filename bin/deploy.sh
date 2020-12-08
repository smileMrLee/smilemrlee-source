#!/usr/bin/env bash
cd  /Users/rongli/workspace/github/smilemrlee-source
mkdocs build
cp -rf /Users/rongli/workspace/github/smilemrlee-source/site/ /Users/rongli/workspace/github/smileMrLee.github.io/ 
cd /Users/rongli/workspace/github/smileMrLee.github.io
git add .
git commit -m "发布提交"
git push
echo "发布github完成"
