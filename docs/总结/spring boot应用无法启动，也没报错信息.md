# spring boot应用无法启动，也没报错信息

## 问题描述

springboot应用昨天还能正常好好启动，忽然之间就启动不了了，也不报任何错误，只见到控制台输出"Stopping service".这个问题已经连续出现过3次了，这次狠下决心要找出个所以然。

在此，先说下个人经历的前面三次无法启动没有报错。

## 举例说明

第一次：和环境有关

>  当某个中间件无法连接的时候，我们的同事在try catch中错误的使用了System.exit()导致异常;
>
> ```java
> try{
>   ……
> }catch(Exception e){
>   System.exit();
>   log.error(e)
> }
> ```

第二次：和jar包冲突有关

> 当时项目中用到了hbase，需要集成hbase，所以引入了hbase-client 2.1.0 版本，但是该包对curator包版本有要求，导致和其他组件的curator版本冲突，最终程序输出的信息中，只有几行INFO日志。
>
> ```
> 2019-09-12 10:39:30.350  INFO 37343 --- [5311@0x040943a6] org.apache.zookeeper.ZooKeeper           : Session: 0x16b72a291d73e73 closed
> 2019-09-12 10:39:30.351  INFO 37343 --- [3a6-EventThread] org.apache.zookeeper.ClientCnxn          : EventThread shut down for session: 0x16b72a291d73e73
> 2019-09-12 10:39:30.566  INFO 37343 --- [tor-Framework-0] o.a.c.f.imps.CuratorFrameworkImpl        : backgroundOperationsLoop exiting
> ```

> 最终通过jar包冲突，不断试错，不断对比和其他能正常启动应用的依赖，才解决冲突。

第三次：和代码编写有关

> 也就是刚刚发生的，让笔者决定狠下心挖掘"无报错信息"的罪魁祸首。一定是有异常的，只是不知道在哪个环节丢失了。
>
> 先说结论：本次"无缘无故"无法启动的原因，其实是昨天笔者开发过程中，代码中添加了一个dubbo服务依赖，但是没有在dubbo xml文件中注册reference，所以导致依赖缺失，最终应用起不来。
>
> 当然，和前面几次一样，控制台，日志文件，没有任何地方有错误信息输出。

## 排查分析

 根据下面这篇文章，给出了提示。

引用：SpringBoot启动项目后自动关闭: https://blog.csdn.net/laoxilaoxi_/article/details/83654186

先说结论：不是没有输出异常，是新版本的Spring boot 在出错后，不再输出错误到控制台了，而是将异常在Application main方法中抛出。

***划重点：新版本Spring boot 2.x 不再输出错误到日志中，将异常在Application main方法中抛出。*** 而低版本Spring boot 1.3.x，1.4.x版本，是会直接在控制台输出错误的。



## 解决方法

**解决：**有了上面的灵感，那好办我在main 启动方法中捕捉，自己打印，不就能看出来错误原因了吗？

事实上，确实应该如此。

最后，笔者在main方法启动spring boot 时，进行一场捕捉并输出日志。然后错误就一目了然了。

```
@Slf4j
@ImportResource("classpath*:spring-*.xml")
@SpringBootApplication
public class SupportApplication {
    public static void main(String[] args) {
        try {
            SpringApplication.run(SupportApplication.class, args);
            System.out.println("Server startup done.");
        }catch (Exception e){
            log.error("服务xxx-support启动报错", e);
        }
    }
}

```

最终在控制台输出久违的异常信息：

```java
2019-09-12 11:18:18.799 ERROR 38420 --- [           main] c.c.xxx.support.xxxSupportApplication    : 服务xxx-support启动报错

org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'xxxController': Injection of resource dependencies failed; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'xxxCoreService': Unsatisfied dependency expressed through field 'xxxSpotService'; nested exception is org.springframework.beans.factory.NoSuchBeanDefinitionException: No qualifying bean of type 'com.test.xxx.api.service.XxxSpotService' available: expected at least 1 bean which qualifies as autowire candidate. Dependency annotations: {@org.springframework.beans.factory.annotation.Autowired(required=true)}
	at org.springframework.context.annotation.CommonAnnotationBeanPostProcessor.postProcessPropertyValues(CommonAnnotationBeanPostProcessor.java:321) ~[spring-context-5.0.10.RELEASE.jar:5.0.10.RELEASE]
	at org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.populateBean(AbstractAutowireCapableBeanFactory.java:1336) ~[spring-beans-5.0.10.RELEASE.jar:5.0.10
```

## 扩展验证

接下来让我们验证下低版本Spring boot 1.3.x，1.4.x版本，是否会直接在控制台输出错误。

下面的实验是基于spring boot 1.4.7版本进行的，低版本的spring boot 都会在控制台或日志文件中先输出错误信息，再退出启动main方法。所以，对于从低版本升到高版本的，请在main启动时，自行捕捉异常。

```java
@Controller
@RequestMapping("/test")
public class TestErrorController {
  /**
   * 1.制造一个不存在的Spring bean；
   * 2.并对其进行依赖；
   * 3.启动应用XxxApplication；
   * 4.控制台有明显报错信息输出；
   * 2019-09-12 10:44:38.014 INFO 37477 --- [ main] o.apache.catalina.core.StandardService : Stopping service [Tomcat]
   * 2019-09-12 10:44:38.026 INFO 37477 --- [ main] utoConfigurationReportLoggingInitializer :
   *
   * <p>Error starting ApplicationContext. To display the auto-configuration report re-run your
   * application with 'debug' enabled. 2019-09-12 10:44:38.155 ERROR 37477 --- [ main] o.s.b.d.LoggingFailureAnalysisReporter :
   * <p>*************************** APPLICATION FAILED TO START ***************************
   * <p>Description:
   * <p>A component required a bean of type
   * 'cn.test.lee.service.TestErrorService' that could not be found.
   * <p>Action:
   * <p>Consider defining a bean of type 'cn.test.service.TestErrorService'
   * in your configuration.
   * <p>Disconnected from the target VM, address: '127.0.0.1:57403', transport: 'socket'
   * <p>Process finished with exit code 1
   */
    @Resource 
    private TestErrorService testErrorService;

    public String testError(){
        testErrorService.testError();
        return "启动就报错了！";
    }
}
```

