### docker 环境下mongoDB 迁移之备份和恢复实战

# 1.背景

需求是这样的，一个朋友最近在某云上通过代理商买了几台服务器，但是和原来的ECS 不在同一个区域。本着长期节约成本的原则，帮朋友搞全网迁移，其中本篇就是mongodb迁移备份还原实战，其中mongodb 为了运维省事，采用docker安装。但是不用担心，实际上docker 无非不过就是类似多一层ssh而已。

我的任务就是将mongoDB从ZJK区迁移到HZ区。

在迁移前，我们假设目标机器已经安装好版本一致的mongo，并且mongo已经启动。

当然，如果还没有安装好，那么，请使用以下三种方式安装。

- 直接下载压缩包解压安装，下载地址：https://www.mongodb.com/download-center/community

  > 解压压缩包
  >
  > 执行命令：sudo mv mongodb-osx-x86_64-4.0.9 /usr/local/mongodb-4.0.9
  >
  > 配置~/.bash_profile 添加export PATH=/usr/local/mongodb-4.0.9/bin:$PATH
  >
  > 如使用zsh，则在~/.zshrc 添加 export PATH=/usr/local/mongodb-4.0.9/bin:$PATH

- docker 方式安装 docker pull mongo:4.2.0-rc2-bionic 

- 使用brew 一键安装 brew install mongo （适合mac 本地安装）

# 2.实战

## 2.1 备份

使用命令先备份，上传文件到杭州区域ECS再导入备份

- 登录到mongdb容器内

> docker exec -it 5f630f4b50d2 /bin/bash
>
> 5f630f4b50d2  是容器的ID，也可以用容器name



- 备份DB

>  mongodump -h 127.0.0.1 --port 27017 -d record -u root -p=rpwd123 -o /backup --authenticationDatabase admin 


上述步骤将会在mongoDB容器内的/backup/ 目录下生成 record 目录，内部包含很多*.json文件。这些json文件就是备份好的文件。


- 一键压缩备份文件夹

> tar -zcvf record.tar.gz backup/record



## 2.2 拷贝文件到目标机器

- 拷贝docker容器文件到真机路径

> docker cp 5f630f4b50d2:/root/backup/record.tar.gz ~/docker/lby-mongo



- 发送文件到目标机器

>  scp record.tar.gz root@218.2**.*.1*:/root/docker/mongo 



- 将目标机器上备份文件拷贝到容器

> docker cp record.tar.gz 605d3a9126cb:/backup/





## 2.3 恢复

- 进入目标机器容器内部

>  docker exec -it 605d3a9126cb /bin/bash



- 解压文件

 gunzip record.tar.gz  

 tar -xvf record.tar

- 登录mongo、创建账号、数据库授权操作

> use admin
>
> db.createUser({user:'root',pwd:' **** ',roles:['userAdminAnyDatabase']})
>
> db.auth('root',' **** ')



上述步骤将会创建一个超级用户root。该root用于管理admin 库里的用户及权限。

> db.createUser({ user: "anyadmin", pwd: "k************************q", roles: ['readWriteAnyDatabase'] })



该步骤创建了一个用于管理全部DB的用户，接下来我们就可以用来anyadmin账号来进行恢复。

- 创建一个同名DB

在容器内执行

> mongo
>
> use record
>
> db.auth('anyadmin', 'k************************q')
>
> db.createCollection("demo")



- 用图形管理工具登录验证是否可以看到DB和集合（略）

- 执行恢复操作

> mongorestore -h localhost:27017 -d record  -u anyadmin -p=k**************q --dir /backup/record --authenticationDatabase admin



正常情况下，你按照上述步骤执行时，应该是一帆风顺的。但如果你不走运遇到了下面的错误。那么你就应该好好检查下，是否有按照上述步骤正确执行。



## 2.4 踩坑笔记

- 报错信息

​        第一次恢复时，执行：` mongorestore -h localhost:27017 -d record --dir /backup/record ` 没有使用用户认证方式报错如下：



```
2020-12-01T03:36:49.405+0000	Failed: record.send_record: error reading database: (Unauthorized) not authorized on record to execute command { listCollections: 1, filter: {}, $db: "record", $readPreference: { mode: "primaryPreferred" } }
2020-12-01T03:36:49.405+0000	0 document(s) restored successfully. 0 document(s) failed to restore.
```



第二次恢复时，执行： ` mongorestore -h localhost:27017 -d record  -u l****  -p=k**** --dir /backup/record `

此时已然那会报错，报权限认证相关报错，只要加上 `--authenticationDatabase admin ` 即可。

此处的用户名和密码均是原来的db的用户名和密码。为了节约时间，我直接按照原db 用户名和密码在新的mongodb上创建并授权。

再执行上述命令，终于成功。



``` 
2020-12-01T06:51:12.936+0000	no indexes to restore
2020-12-01T06:51:12.936+0000	finished restoring record.2t0.cn (5287717 documents, 0 failures)
****
2020-12-01T06:52:51.920+0000	[######################..]  record.send_record  4.15GB/4.33GB  (95.8%)
****
2020-12-01T06:52:59.043+0000	[########################]  record.send_record  4.33GB/4.33GB  (100.0%)
2020-12-01T06:52:59.043+0000	restoring indexes for collection record.send_record from metadata
2020-12-01T06:53:52.512+0000	finished restoring record.send_record (4075860 documents, 0 failures)
2020-12-01T06:53:52.512+0000	14808894 document(s) restored successfully. 0 document(s) failed to restore.
```



当然，整个迁移中其实还有很多坑的，比如安装docker时，由于需要配套使用docker-compose组件快捷部署容器，所以需要安装docker-compose，在安装的过程中遇到pip 命令不存在等问题。

详见：[[总结] 解决docker-compose 安装失败](https://changle.blog.csdn.net/article/details/110423558)


