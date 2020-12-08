### 一文彻底搞定Spring事务传播机制
## 一、事务传播机制介绍

我们开发中经常遇到同时操作多张表，多次操作数据库，那么在很多场景下，当我们的业务需要嵌套调用事务方法，而其中某个方法出现异常的时候，会根据异常点出现的地方，适时调整回滚方案。是全量回滚还是只回滚某个点？此时spring 事务传播就可以完美解决此问题。

以下是Spring boot 七大传播机制介绍：

| 类型                      | 说明                                                         | 方法执行时-事务个数 |
| ------------------------- | ------------------------------------------------------------ | ------------------- |
| Propagation.REQUIRED      | required 要求有事务，有事务则加入到事务，如果没有，则新建事务再执行。同时提交、同时回滚。 | 1个事务             |
| Propagation.SUPORTS       | suports 支持在事务中运行，如果没有，就以非事务执行。有事务则同时提交，无事务互不影响。 | 0或1个事务          |
| Propagation.MANDATORY     | mandatory 使用当前事务，如果没有事务，则抛出异常。同时提交、同时回滚。 | 复用1个事务         |
| Propagation.REQUIRED_NEW  | required_new 无论有无事务，新建事务进行执行。两个独立事务互不影响。 | 新建1个事务         |
| Propagation.NOT_SUPPORTED | not_supported 不支持在事务中执行，如果存在事务，则挂起事务。事务回滚不影响子方法 | 最多1个事务         |
| Propagation.NEVER         | never 不支持在事务中执行，如果有事务，则抛出异常。不需要事务，互不影响。 | 必须0个事务         |
| Propagation.NESTED        | nested 如果当前存在事务，则嵌套事务执行，如果当前没有事务，则新建事务再执行。 主方法savepoint保存点异常，不影响主方法提交事务。主方法异常则整体回滚。 | 嵌套事务，1个事务   |

## 二、重点理解

为了便于理解事务方法嵌套调用，特写伪编码如下：

```java
ServiceA{
    @Transactional(rollbackFor = Exception.class, propagation= Propagation.REQUIRED)
    methodA(Parmas ...){
       doSomethingA(...);
       // 此处嵌套调用服务B的事务方法
       serviceB.methodB(params ...);       
    }
}

ServiceB{
    @Transactional(rollbackFor = Exception.class, propagation= Propagation.NESTED)
    methodB(Params ...){
        doSomethingB(...);
    }
}
```

![点击并拖拽以移动](data:image/gif;base64,R0lGODlhAQABAPABAP///wAAACH5BAEKAAAALAAAAAABAAEAAAICRAEAOw==)

两个事务之间，根本配置的传播机制不一样，而表现的结果不一样。

其他的事务传播机制比如Required，Never等都好理解，参看上表，注意红色部分。一直以来，我个人发现虽然很早以前就认真学过，但每次重新看这块知识点的时候，尤其是对nested都会理解不准。

为此，查阅了很多资料，同时，专门编码去验证该nested传播机制的特别之处。总之，你只要记住：

NESTED的回滚特性

- 主事务和嵌套事务属于同一个事务
- 嵌套事务出错回滚不会影响到主事务
- 主事务回滚会将嵌套事务一起回滚了

如果你还是不能很好理解和掌握，那么花上十分钟，下载项目，自己运行一下吧。

## 三、编码验证

github地址：https://github.com/smileMrLee/spring-nested-demo

上面的demo中，我们设计两个接口test/required、test/nested 分别用来测试required和nested的传播机制。

通过入参中的remark是否包含：childError 和 mainError 文本来控制主方法和子方法是否抛出异常，从而进行回滚。

**required case1**

required主方法和required子方法正常提交：http://localhost:8080/test/required?name=changle&remark=required_required

**required case2**

required主方法因required子方法异常回滚：http://localhost:8080/test/required?name=lisi&remark=required_required_childError

**required Case3**

required主方法异常连带required子方法异常回滚：http://localhost:8080/test/required?name=lisi&remark=required_required_childError



**nested Case1**

required主方法正常提交-nested子方法异常回滚：http://localhost:8080/test/nested?name=lisi&remark=required_required_childError

**nested Case2**

required主方法异常回滚-连带nested子方法回滚：http://localhost:8080/test/nested?name=lisi&remark=required_required_mainError

## 四、核心代码

**web controller**

```java
@Slf4j
@RestController
@RequestMapping("/test")
public class CrudTestController {
    @Resource
    private UserService userService;

    @GetMapping("/required")
    public String required(String name, String remark){
        try {
            boolean result = userService.createUserRequired(name, remark);
            if (result){
                return "成功";
            }else {
                return "失败";
            }
        }catch (Exception e){
            log.error("执行required事务例子异常", e);
            return "异常";
        }
    }

    @GetMapping("/nested")
    public String nested(String name, String remark){
        try {
            boolean result = userService.createUserNested(name, remark);
            if (result){
                return "成功";
            }else {
                return "失败";
            }
        }catch (Exception e){
            log.error("执行nested事务例子异常", e);
            return "异常";
        }
    }
}
```

![点击并拖拽以移动](data:image/gif;base64,R0lGODlhAQABAPABAP///wAAACH5BAEKAAAALAAAAAABAAEAAAICRAEAOw==)

**serviceA main主方法嵌套调用**

```java
@Slf4j
@Service
public class UserService {
    @Resource
    private UserMapper userMapper;
    @Resource
    private UserMoneyService userMoneyService;

    @Transactional(rollbackFor = Exception.class, propagation= Propagation.REQUIRED)
    public Boolean createUserRequired(String userName, String remark){
        UserPo userPo = UserPo.builder()
                .userName(userName)
                .realName("真实的"+userName)
                .passWord("REQUIRED")
                .remark("REQUIRED:" + remark).build();
        userMapper.insert(userPo);
        userMoneyService.createUserBalance(userPo.getId(), remark);
        if (remark.contains("mainError")) {
            throw new RuntimeException("mainMethod 手动抛错");
        }
        return true;
    }

    @Transactional(rollbackFor = Exception.class, propagation= Propagation.REQUIRED)
    public Boolean createUserNested(String userName, String remark){
        UserPo userPo = UserPo.builder()
                .userName(userName)
                .realName("真实的"+userName)
                .passWord("REQUIRED")
                .remark("REQUIRED:" + remark).build();
        userMapper.insert(userPo);
        try {
            userMoneyService.createUserBalanceNested(userPo.getId(), remark);
        }catch (Exception e){
            log.error("创建用户余额时异常|userName:{},remark:{}", userName, remark, e);
        }
        if (remark.contains("mainError")) {
            throw new RuntimeException("mainMethod 手动抛错");
        }
        return true;
    }

}
```

![点击并拖拽以移动](data:image/gif;base64,R0lGODlhAQABAPABAP///wAAACH5BAEKAAAALAAAAAABAAEAAAICRAEAOw==)

**serviceB child子方法被嵌套调用**

```java
@Slf4j
@Service
public class UserMoneyService {
    @Resource
    private UserMoneyMapper userMoneyMapper;

    @Transactional(rollbackFor = Exception.class, propagation= Propagation.REQUIRED)
    public boolean createUserBalance(Integer userId, String remark){
        userMoneyMapper.insert(UserMoneyPo.builder()
                .userId(userId)
                .balance(11)
                .remark("REQUIRED:"+remark).build());
        if (remark.contains("childError")) {
            throw new RuntimeException("childMethod 手动抛错");
        }
        return true;
    }

    @Transactional(rollbackFor = Exception.class, propagation= Propagation.NESTED)
    public boolean createUserBalanceNested(Integer userId, String remark){
        userMoneyMapper.insert(UserMoneyPo.builder()
                .userId(userId)
                .balance(11)
                .remark("NESTED:"+remark).build());
        log.error("余额创建成功-------手动回滚-------");
        if (remark.contains("childError")) {
            throw new RuntimeException("childMethod 手动抛错");
        }
        return true;
    }

    
}
```

本文源码：github地址：https://github.com/smileMrLee/spring-nested-demo