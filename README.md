# VVSequelize

[![Version](https://img.shields.io/cocoapods/v/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)
[![License](https://img.shields.io/cocoapods/l/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)
[![Platform](https://img.shields.io/cocoapods/p/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)

## 功能
* [x] 根据Class生成数据表
* [x] 增删改查,insert,update,upsert,delele,drop...
* [x] Where语句生成,可满足大部分常规场景
* [x] 数据库加解密(SQLCipher)
* [x] 原生SQL语句支持
* [x] 常规查询支持,max,min,sum,count...
* [x] 主键支持(可自动主键),唯一性约束支持.
* [x] Queue,Transaction支持(使用FMDB,串行Queue)
* [x] Object直接处理
* [x] 数据存储,OC类型支持: NSData, NSURL, NSSelector, NSValue, NSDate, NSArray, NSDictionary, NSSet,...
* [x] 数据存储,C类型支持: char *, struct, union
* [x] 子对象存储为Json字符串
* [x] OrmModel查询缓存

## 待完成
* [ ] FTS支持
* [ ] 防SQL注入
* [ ] 即将移除三方`Dictionary/Object`工具支持

## 改动(0.2.0)
1. 新增glob支持.
2. fix bug.

## 安装
目前版本基本可食用,以后根据需求不定期更新.
```ruby
pod 'VVSequelize'
```
如果要在Podfile中是使用`use_frameworks!`, 需要在 Podfile 结尾加上hook,为 FMDB 添加头文件搜索路径,解决FMDB编译失败的问题.
```ruby
target 'targetxxxx' do
    pod 'VVSequelize', :git => 'https://github.com/pozi119/VVSequelize.git'
end

post_install do |installer|
    print "Add 'SQLCipher' to FMDB 'HEADER_SEARCH_PATHS' \n"
    installer.pods_project.targets.each do |target|
        if target.name == "FMDB"
            target.build_configurations.each do |config|
                header_search = {"HEADER_SEARCH_PATHS" => "SQLCipher"}
                config.build_settings.merge!(header_search)
            end
        end
    end
end
```
## 注意
1. 请先设置`Dictionary/Object`互转工具,若不设置, 则大部分操作只能支持Dictionary.
2. 子对象会保存成为Json字符串,子对象内的NSData也会保存为16进制字符串.
3. 含有子对象时,请确保不会循环引用,否则`Dictionary/Object`互转会死循环,请将相应的循环引用加入互转黑名单. 黑名单可使用`YYModel`和`MJExtension`的设置.
4. VVKeyValue仅用于本工具,不适用常规的Json转对象.
5. 集合类型(Array,Dictionary,Set)进行转换时

## 用法

此处主要列出一些基本用法,详细用法请阅读代码注释.

### 设置`Dictionary/Object`互转工具  
一般项目中使用`Dictionary/Object`互转工具时,基本都会存在对象属性名和字典的字段名不一致的情况, 会进行重新映射.
 
这时请务必设置另一个`Dictionary/Object`互转工具,或者是本项目自带的`VVKeyValue`.

比如项目中用的`YYModel`,那么本工具中请使用自带的`VVKeyValue`或者`MJExtension`

此处建议使用`VVKeyValue`,经过多次修改,已经可用,且专门针对本数据库存储数据做了处理,如果出现问题,请提[issue](https://github.com/pozi119/VVSequelize/issues/new),并使用第三方替代.

设置方法如下:

```objc
// 设置使用自带的字典/对象互转工具
[VVSequelize useVVKeyValue];
```
在VVKeyValue出现问题时可使用第三方,但存储套嵌对象时也可能有问题:
```objc
// 使用第三方的字典/互转工具
[VVSequelize setKeyValuesToObject:^id(Class cls, NSDictionary *dic) {
    return [cls mj_objectWithKeyValues:dic];
}];
[VVSequelize setKeyValuesArrayToObjects:^NSArray *(Class cls, NSArray *dicArray) {
    return [cls mj_objectArrayWithKeyValuesArray:dicArray];
}];
[VVSequelize setObjectToKeyValues:^id(Class cls, id object) {
    return [object mj_keyValues];
}];
[VVSequelize setObjectsToKeyValuesArray:^NSArray *(Class cls, NSArray *objects) {
    return [cls mj_keyValuesArrayWithObjectArray:objects];
}];
```

### 定义ORM模型 
可自定义表名,各字段的参数,不保存的字段, 存放的数据库文件,是否记录创建和更新时间等.

生成的模型将使用dbName和tableName生成的字符串作为Key,存放至一个模型池中,若下次使用相同的数据库和表名创建模型,这先从模型池中查找.

示例如下:

```objc
self.vvdb = [[VVDataBase alloc] initWithDBName:@"mobiles.sqlite" dirPath:nil encryptKey:nil];
VVOrmSchemaItem *column1 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"mobile",@"pk":@(YES)}];
self.mobileModel = [VVOrmModel ormModelWithClass:VVTestMobile.class
                                         manuals:@[column1]
                                        excludes:nil
                                       tableName:@"mobiles"
                                        dataBase:self.vvdb
                                          logAt:YES];

```
### 增删改查
使用ORM模型进行增删改查等操作.

示例如下:

```objc
NSInteger count = [self.mobileModel count:nil];
BOOL ret = [self.mobileModel increase:nil field:@"times" value:-1];
NSArray *array = [self.mobileModel findAll:nil orderBy:nil range:NSMakeRange(0, 10)];
...
```

### 生成Where语句
采用了类似sequelize.js的方式生成where语句.具体说明请参考```VVSqlGenerator.h```中的注释.

示例如下:

```objc
NSArray *conditions = @[
    @{@"name":@"zhangsan", @"age":@(26)},
    @{@"$or":@[@{@"name":@"zhangsan",@"age":@(26)},@{@"age":@(30)}]},
    @{@"age":@{@"$lt":@(30)}},
    @{@"$or":@[@{@"name":@"zhangsan"},@{@"age":@{@"$lt":@(30)}}]},
    @{@"type":@{@"$in":@[@"a",@"b",@"c"]}},
    @{@"score":@{@"$between":@[@"20",@"40"]}},
    @{@"text":@{@"$like":@"%%haha"}},
    @{@"score":@{@"$gt":@(60),@"$lte":@(80)}},
    @{@"age":@{@"$or":@[
            @{@"age":@{@"$gt":@(10)}},
            @{@"age":@{@"$lte":@(30)}}
        ]},
        @"name":@{@"$notLike":@"%%zhangsan"},
        @"$or":@[@{@"score":@{@"$gt":@(60),@"$lte":@(80)}},@{@"score":@{@"$gt":@(20),@"$lte":@(40)}}]
    }
];
for (NSDictionary *condition in conditions) {
    NSString *where = [VVSqlGenerator where:condition];
    NSLog(@"where sentence : %@", where);
}
```

## Author

Valo Lee, pozi119@163.com

## License

VVSequelize is available under the MIT license. See the LICENSE file for more info.
