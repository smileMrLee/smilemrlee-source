### 开始前必读

本项目基于 spring boot + sharding-jdbc + mybatis + mysql搭建，用作测试验证sharding-jdbc 实现数据库分库分表。
下载启动本项目前，请先执行DDL.sql 初始化数据库。

- DDL.sql 文件位于本项目根路径下。

- 启动前，请先修改 mysql 连接信息，确保连接账号密码无误。


### 实战

集成sharding-jdbc总共需要以下几步


#### 1. pom依赖引入sharding-jdbc 及 mybatis组件包


```xml
    <!-- mysql driver -->
		<dependency>
			<groupId>mysql</groupId>
			<artifactId>mysql-connector-java</artifactId>
			<scope>runtime</scope>
		</dependency>
		<!-- mybatis -->
		<dependency>
			<groupId>com.baomidou</groupId>
			<artifactId>mybatis-plus-boot-starter</artifactId>
			<version>3.1.1</version>
		</dependency>
		<!-- sharding-jdbc start -->
		<dependency>
			<groupId>io.shardingsphere</groupId>
			<artifactId>sharding-jdbc-spring-boot-starter</artifactId>
			<version>3.1.0</version>
		</dependency>
		<dependency>
			<groupId>io.shardingsphere</groupId>
			<artifactId>sharding-jdbc-spring-namespace</artifactId>
			<version>3.1.0</version>
		</dependency>
		<!-- sharding-jdbc end -->
```

#### 2. 配置数据源


```properties
# test0数据源
sharding.jdbc.datasource.test0.type=com.zaxxer.hikari.HikariDataSource
sharding.jdbc.datasource.test0.driver-class-name=com.mysql.cj.jdbc.Driver
sharding.jdbc.datasource.test0.jdbc-url=jdbc:mysql://127.0.0.1:3306/test0?useUnicode=true&useJDBCCompliantTimezoneShift=true&useLegacyDatetimeCode=false&serverTimezone=UTC
sharding.jdbc.datasource.test0.username=root
sharding.jdbc.datasource.test0.password=123456

…… 

# testn数据源
sharding.jdbc.datasource.test${n}.type=com.zaxxer.hikari.HikariDataSource
sharding.jdbc.datasource.test${n}.driver-class-name=com.mysql.cj.jdbc.Driver
sharding.jdbc.datasource.test${n}.jdbc-url=jdbc:mysql://127.0.0.1:3306/test${n}?useUnicode=true&useJDBCCompliantTimezoneShift=true&useLegacyDatetimeCode=false&serverTimezone=UTC
sharding.jdbc.datasource.test${n}.username=root
sharding.jdbc.datasource.test${n}.password=123456

# 注意此处的"test0" 到 "test${n}" 按照实际需要配置分库需要的数据源个数。 ${n} 改为实际的库编号。 
# 虽然此处的test${n} 中的n不是必须填写数字，但是为了保持好的规范，我们强烈建议按照阿拉伯数字1~n对数据库进行编码。

```


#### 3. 配置数据库database分库策略、表table分表策略


```properties
# 分库策略
# 水平拆分的数据库（表） 配置分库，分库主要取决于id列
sharding.jdbc.config.sharding.default-database-strategy.inline.sharding-column=id
sharding.jdbc.config.sharding.default-database-strategy.inline.algorithm-expression=test$->{id % 3}
```


```properties
# 分表策略 
# 其中car为逻辑表 分表主要取决于count列，⚠️此处应该选择一个均匀分布的列值，本项目为了简便才随机选择count列。
sharding.jdbc.config.sharding.tables.t_car.actual-data-nodes=test$->{0..2}.t_car_$->{0..1}
sharding.jdbc.config.sharding.tables.t_car.table-strategy.inline.sharding-column=count
```


#### 4. 编码实现



- 详细参考源码，entity 中表名使用逻辑表表名。
@TableName("t_car")



- 在启动类添加注解
@MapperScan("com.lee.sharding.jdbc.demo.mapper")

然后编写service 和 controller进行crud



#### 5. http调用验证
   保存车辆信息：http://localhost:8080/car/save  
   查询车辆列表：http://localhost:8080/car/get

#### 6.github开源地址
https://github.com/smileMrLee/sharding-jdbc-demo