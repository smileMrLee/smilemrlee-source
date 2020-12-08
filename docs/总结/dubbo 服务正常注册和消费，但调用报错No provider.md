dubbo 服务正常注册和消费，但调用报错No provider
# 问题现象
dubbo 服务提供者正常注册，消费者也正常消费，在dubbo-admin上观察没问题。本地服务proxy也正常生成，但无法调用成功。每次调用都是下面的错误信息：
> Failed to invoke the method getAllowUrls in the service com.xxx.bss.api.AcxxxQueryApi. No provider available for the service com.xxx.bss.api.AcxxxQueryApi:dev from registry 10.0.10.21:15311 on the consumer 10.200.190.182 using the dubbo version 2.6.4. Please check if the providers have been started and registered.

这个问题隐蔽很，应用启动没问题，也无启动报错信息，甚至warn都没有。

# 排查分析
项目在添加新的二方包之后，原来好好的dubbo忽然就调不通了。一开始以为只是个别服务，尝试了所有dubbo服务之后，都不成功。报错都是一样。检查了dubbo admin，发现提供者和消费者都正常。
于是朝着包冲突方向去排查，把代码回退到可以正常调用dubbo服务的版本，也就是未添加新二方包的版本。

于是分析可以调用的版本和调用失败的版本的包依赖。
最后发现，不能正常调用的代码版本中，没有依赖netty-3.2.5.Final.jar 这个包，于是将该包手动强制依赖到项目中。就可以正常调用。

正常情况下，dubbo 包都会传递依赖netty包进来的，为什么netty包会被干掉呢。仔细排查代码中也没有任何地方进行exclusion.于是怀疑是maven 仲裁的时候，选用了二方包依赖进来的包中某个包恰巧把netty包给干掉了。导致jar 包依赖短路，短路的包把依赖丢弃了。从而少了netty包。

最后排查结果确实如此，是因为我新引进来的二方包，将dubbo 包的依赖全部进行exclusion了。

如下图是包缺失的证据：
![netty包缺失](/img/netty-jar-lost.png)
netty 包被二方包排除依赖的证据：
![netty包被隐形排除](/img/netty-jar-exclusion.png)
# 解决方法
```java
			<dependency>
                <groupId>org.jboss.netty</groupId>
                <artifactId>netty</artifactId>
                <version>${netty_version}</version>
            </dependency>
<netty_version>3.2.5.Final</netty_version>
```
即可解决。不同的dubbo 版本换成对应的netty版本即可。

# 总结
虽然问题解决了，但是有必要说两句。
1.二方包想要减少进入业务方代码，exclusion是好的想法，但exclusion不够彻底。如果直接exclusion掉dubbo，就不会造成maven仲裁选用缺失依赖的dubbo。
2.dubbo 报错也不够友好，很明显这种异常并不是因为没有provider造成的，而是底层网络框架包丢失了。异常应该更加细化和详尽。