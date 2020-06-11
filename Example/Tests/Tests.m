//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo Lee on 06/06/2018.
//  Copyright (c) 2018 Valo Lee. All rights reserved.
//

#import "VVTestClasses.h"
#import <VVSequelize/VVSequelize.h>

@import XCTest;

@interface Tests : XCTestCase
@property (nonatomic, strong) VVDatabase *vvdb;
@property (nonatomic, strong) VVOrm *mobileModel;
@property (nonatomic, strong) VVOrm *ftsModel;
@property (nonatomic, strong) VVOrmView *mobileView;
@end

@implementation Tests

- (void)setUp
{
    [super setUp];

    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *targetPath = [path stringByAppendingPathComponent:@"mobiles.sqlite"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:targetPath]) {
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"mobiles.sqlite" ofType:nil];
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:targetPath error:nil];
    }

    NSString *vvdb = [path stringByAppendingPathComponent:@"mobiles.sqlite"];
    self.vvdb = [[VVDatabase alloc] initWithPath:vvdb];

    NSString *dbpath = [path stringByAppendingPathComponent:@"test1.sqlite"];

    @autoreleasepool {
        VVDatabase *db1 = [[VVDatabase alloc] initWithPath:dbpath];
//        db1 = nil;
        VVDatabase *db2 = [[VVDatabase alloc] initWithPath:dbpath];
//        db2 = nil;
        VVDatabase *db3 = [[VVDatabase alloc] initWithPath:dbpath];
        if (db1 && db2 && db3) {
        }
    }

    [self.vvdb registerMethod:VVTokenMethodSequelize forTokenizer:@"sequelize"];
//    [self.vvdb setTraceHook:^int(unsigned int mask, void * _Nonnull stmt, void * _Nonnull sql) {
//        NSLog(@"mask: %@, sql: %s",@(mask),(char *)sql);
//        return 0;
//    }];

    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestMobile.class];
    config.primaries = @[@"mobile"];
    self.mobileModel = [VVOrm ormWithConfig:config name:@"mobiles" database:self.vvdb];
    NSUInteger ftsTokenParm = VVTokenMaskDefault | 15;
    NSString *tokenizer = [NSString stringWithFormat:@"sequelize %@", @(ftsTokenParm)];
    VVOrmConfig *ftsConfig = [VVOrmConfig ftsConfigWithClass:VVTestMobile.class module:@"fts5" tokenizer:tokenizer indexes:@[@"industry"]];

    self.ftsModel = [VVOrm ormWithConfig:ftsConfig name:@"fts_mobiles" database:self.vvdb];
    //复制数据到fts表
    NSUInteger count = [self.ftsModel count:nil];
    if (count == 0) {
        for (NSUInteger i = 3; ; i++) {
            VVTestMobile *mobile = [self.mobileModel findAll:nil orderBy:nil limit:1 offset:i].firstObject;
            if (!mobile) break;
            [self.ftsModel insertOne:mobile];
        }
        //[self.vvdb excute:@"INSERT INTO fts_mobiles (mobile, province, city, carrier, industry, relative, times) SELECT mobile, province, city, carrier, industry, relative, times FROM mobiles"];
    }
    self.mobileView = [[VVOrmView alloc] initWithName:@"xian_mobiles" orm:self.mobileModel condition:@{ @"city": @"西安" } temporary:NO columns:nil];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//MARK: - 普通表
- (void)testFind
{
    NSArray *array = [self.mobileModel findAll:nil orderBy:nil limit:10 offset:0];
    array = [self.mobileModel findAll:nil orderBy:@[@"mobile", @"city"].desc limit:10 offset:0];
    array = [self.mobileModel findAll:@"mobile > 15000000000" orderBy:@"mobile ASC,city DESC" limit:5 offset:0];
    id obj = [self.mobileModel findOne:nil orderBy:@"mobile DESC,city ASC"];
    if (array && obj) {
    }
}

- (void)testInTransaction
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger i = 0; i < 100; i++) {
        VVTestMobile *mobile = [VVTestMobile new];
        mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i", arc4random_uniform(99), arc4random_uniform(9999), arc4random_uniform(9999)];
        mobile.province = @"四川";
        mobile.city = @"成都";
        mobile.industry = @"IT";
        mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
        [array addObject:mobile];
    }
    BOOL ret = [self.mobileModel insertMulti:array];
    NSLog(@"ret: %@", @(ret));
}

- (void)testMobileModel
{
    NSInteger count = [self.mobileModel count:nil];
    BOOL ret = [self.mobileModel increase:nil field:@"times" value:-1];
    NSArray *array = [self.mobileModel findAll:nil orderBy:nil limit:10 offset:0];
    NSLog(@"count: %@", @(count));
    NSLog(@"array: %@", array);
    NSLog(@"ret: %@", @(ret));
}

- (void)testCreate
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger i = 0; i < 100; i++) {
        VVTestMobile *mobile = [VVTestMobile new];
        mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i", arc4random_uniform(99), arc4random_uniform(9999), arc4random_uniform(9999)];
        mobile.province = @"四川";
        mobile.city = @"成都";
        mobile.industry = @"IT";
        mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
        [array addObject:mobile];
    }
    BOOL ret = [self.mobileModel insertOne:array[0]];
    NSLog(@"ret: %@", @(ret));
    ret = [self.mobileModel insertMulti:array];
    NSLog(@"ret: %@", @(ret));
}

- (void)testUpdate
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger i = 0; i < 100; i++) {
        VVTestMobile *mobile = [VVTestMobile new];
        mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i", arc4random_uniform(99), arc4random_uniform(9999), arc4random_uniform(9999)];
        mobile.province = @"四川";
        mobile.city = @"成都";
        mobile.industry = @"IT";
        mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
        [array addObject:mobile];
    }
    VVTestMobile *mobile = [self.mobileModel findOne:nil];
    mobile.province = @"四川";
    mobile.city = @"成都";
    mobile.industry = @"IT";
    BOOL ret = [self.mobileModel updateOne:mobile];
    NSLog(@"ret: %@", @(ret));
    NSArray *objects = [self.mobileModel findAll:nil orderBy:nil limit:9 offset:1];
    for (VVTestMobile *m in objects) {
        m.province = @"四川";
        m.city = @"成都";
        m.industry = @"IT";
    }
    ret = [self.mobileModel updateMulti:objects];
    NSLog(@"ret: %@", @(ret));
    ret = [self.mobileModel upsertOne:array[0]];
    NSLog(@"ret: %@", @(ret));
    ret = [self.mobileModel upsertMulti:array];
    NSLog(@"ret: %@", @(ret));
}

- (void)testMaxMinSum
{
    id max = [self.mobileModel max:@"relative" condition:nil];
    id min = [self.mobileModel min:@"relative" condition:nil];
    id sum = [self.mobileModel sum:@"relative" condition:nil];
    NSLog(@"max : %@, min : %@, sum : %@", max, min, sum);
}

- (void)testOrmModel
{
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestPerson.class];
    config.primaries = @[@"idcard"];
    config.uniques = @[@"mobile", @"arr", @"mobile"];
    config.notnulls = @[@"name", @"arr", @"name"];
    config.whiteList = @[@"idcard", @"name", @"mobile", @"age"];
    [config treate];

    VVOrm *personModel1 = [VVOrm ormWithConfig:config name:@"persons" database:self.vvdb];
    NSUInteger maxrowid = [personModel1 maxRowid];
//    NSLog(@"%@", personModel);
    NSLog(@"maxrowid: %@", @(maxrowid));
    NSString *sql = @"UPDATE \"persons\" SET \"name\" = \"lisi\" WHERE \"idcard\" = \"123456\"";
    VVDatabase *vvdb = personModel1.vvdb;
    BOOL ret = [vvdb excute:sql];
    NSLog(@"%@", @(ret));
}

- (void)testRelativeORM {
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestPerson.class];
    config.primaries = @[@"idcard"];

    VVOrmConfig *ftsconfig = [VVOrmConfig configWithClass:VVTestPerson.class];
    ftsconfig.fts = YES;
    ftsconfig.ftsModule = @"fts5";
    ftsconfig.ftsTokenizer = @"sequelize";
    ftsconfig.indexes = @[@"name"];

    VVOrm *orm = [VVOrm ormWithConfig:config name:@"relative_person" database:self.vvdb];
    VVOrm *ftsorm = [VVOrm ormWithConfig:ftsconfig relative:orm content_rowid:@"idcard"];

    NSDate *now = [NSDate date];
    VVTestPerson *p1 = [VVTestPerson new];
    p1.idcard = @"10001";
    p1.name = @"张三";
    p1.age = 19;
    p1.birth = now;
    p1.mobile = @"13112344312";

    VVTestPerson *p2 = [VVTestPerson new];
    p2.idcard = @"10002";
    p2.name = @"李四";
    p2.age = 22;
    p2.birth = now;
    p2.mobile = @"13223245678";

    VVTestPerson *p3 = [VVTestPerson new];
    p3.idcard = @"10003";
    p3.name = @"王五";
    p3.age = 21;
    p3.birth = now;
    p3.mobile = @"13365457676";

    [orm deleteWhere:nil];
    [orm insertMulti:@[p1, p2, p3]];
    NSArray *r1 = [ftsorm findAll:nil];
    [orm deleteOne:p2];
    NSArray *r2 = [ftsorm findAll:nil];
    p3.name = @"wangwu";
    [orm updateOne:p3];
    NSArray *r3 = [ftsorm findAll:nil];
    if (r1 && r2 && r3) {
    }
}

- (void)testClause
{
    VVSelect *select =  [VVSelect new];
    select.table(@"mobiles");
    select.where(@"relative".lt(@(0.3)).and(@"mobile".gte(@(1600000000))).and(@"times".gte(@(0))));
    NSLog(@"%@", select.sql);
    select.where(@{ @"city": @"西安", @"relative": @(0.3) });
    NSLog(@"%@", select.sql);
    select.where(@[@{ @"city": @"西安", @"relative": @(0.3) }, @{ @"relative": @(0.7) }]);
    NSLog(@"%@", select.sql);
    select.where(@"relative".lt(@(0.3)));
    NSLog(@"%@", select.sql);
    select.where(@"     where relative < 0.3");
    NSLog(@"%@", select.sql);
    select.groupBy(@"city");
    NSLog(@"%@", select.sql);
    select.groupBy(@[@"city", @"carrier"]);
    NSLog(@"%@", select.sql);
    select.groupBy(@" group by city carrier");
    NSLog(@"%@", select.sql);
    select.having(@"relative".lt(@(0.2)));
    NSLog(@"%@", select.sql);
    select.groupBy(nil);
    NSLog(@"%@", select.sql);
    select.orderBy(@[@"city", @"carrier"]);
    NSLog(@"%@", select.sql);
    select.orderBy(@" order by relative");
    NSLog(@"%@", select.sql);
    select.limit(10);
    NSLog(@"%@", select.sql);
    select.distinct(YES);
    NSLog(@"%@", select.sql);
}

- (void)testExample
{
    NSDate *now = [NSDate date];
    VVTestPerson *person = [VVTestPerson new];
    person.idcard = @"123123";
    person.name = @"zhangsan";
    person.age = 19;
    person.birth = now;
    person.mobile = @"123123123";
    NSDictionary *dic = person.vv_keyValues;
    NSLog(@"%@", dic);
//    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

- (void)testView {
    BOOL exist = self.mobileView.exist;
    if (!exist) {
        BOOL ret = [self.mobileView createView];
        XCTAssert(ret == YES);
    }
    NSArray *array = [self.mobileView findAll:@{ @"industry": @"木材" }];
    XCTAssert(array.count > 0);
}

- (void)testObjEmbed
{
    NSDate *now = [NSDate date];
    VVTestPerson *person = [VVTestPerson new];
    person.idcard = @"123123";
    person.name = @"zhangsan";
    person.age = 19;
    person.birth = now;
    person.mobile = @"123123123";
    VVTestMobile *mobile = [VVTestMobile new];
    mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i", arc4random_uniform(99), arc4random_uniform(9999), arc4random_uniform(9999)];
    mobile.province = @"四川";
    mobile.city = @"成都";
    mobile.industry = @"IT";
    mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
    VVTestOne *one = [VVTestOne new];
    one.oneId = 1;
    one.person = person;
    one.mobiles = @[mobile];
    one.friends = [NSSet setWithArray:@[person]];
    one.flag = @"hahaha";
    one.dic = @{ @"a": @(1), @"b": @(2) };
    one.arr = @[@(1), @(2), @(3)];

    NSDictionary *oneDic = one.vv_keyValues;
    NSLog(@"dic: %@", oneDic);
    VVTestOne *nOne = [VVTestOne vv_objectWithKeyValues:oneDic];
    NSLog(@"obj: %@", nOne);
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestOne.class];
    config.primaries = @[@"oneId"];
    VVOrm *orm = [VVOrm ormWithConfig:config];
    [orm upsertOne:one];
    VVTestOne *mOne = [orm findOne:nil];
    NSLog(@"mOne: %@", mOne);
}

- (void)testMixDataTypes
{
    VVTestMix *mix = [VVTestMix new];
    mix.num = @(10);
    mix.cnum = 9;
    mix.val = [NSValue valueWithRange:NSMakeRange(0, 20)];
    mix.decNum = [NSDecimalNumber decimalNumberWithString:@"2.53"];
    mix.size = CGSizeMake(90, 30);
    mix.point = CGPointMake(5, 75);
    VVTestUnion un;
    un.num = 65535;
    mix.un =  un;
    VVTestStruct stru;
    stru.ch = 'x';
    stru.num = 8;
    mix.stru = stru;
    NSString *temp = @"hahaha";
    char *str = (char *)[temp UTF8String];
    mix.str = str;
    mix.sa = 'b';
    mix.unknown = (void *)str;
    mix.selector = NSSelectorFromString(@"help:");
    NSDictionary *mixkvs = mix.vv_keyValues;
    NSLog(@"mix: %@", mixkvs);
    VVTestMix *mix2 = [VVTestMix vv_objectWithKeyValues:mixkvs];
    NSLog(@"mix2: %@", mix2);
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestMix.class];
    config.primaries = @[@"num"];
    VVOrm *orm = [VVOrm ormWithConfig:config];
    [orm upsertOne:mix];
    VVTestMix *mix3 = [orm findOne:nil];
    NSLog(@"mix3: %@", mix3);
}

- (void)testUnion
{
    VVTestUnion un;
    un.ch = 3;
    NSValue *value = [NSValue valueWithBytes:&un objCType:@encode(VVTestUnion)];
    VVTestUnion ne;
    [value getValue:&ne];
    NSLog(@"value: %@", value);
    CLLocationCoordinate2D coordinate2D = CLLocationCoordinate2DMake(30.546887, 104.064271);
    NSValue *value1 = [NSValue valueWithCoordinate2D:coordinate2D];
    CLLocationCoordinate2D coordinate2D1 = value1.coordinate2DValue;
    NSString *string = NSStringFromCoordinate2D(coordinate2D);
    CLLocationCoordinate2D coordinate2D2 = Coordinate2DFromString(@"{adads3.0,n5.2vn}");

    NSLog(@"string: %@, coordinate2D1: {%f,%f}, coordinate2D2: {%f,%f}", string, coordinate2D1.latitude, coordinate2D1.longitude, coordinate2D2.latitude, coordinate2D2.longitude);
}

- (void)testColletionDescription
{
    NSArray *array1 = @[@(1), @(2), @(3)];
    NSArray *array2 = @[@"1", @"2", @"3", array1];
    NSDictionary *dic3 = @{ @"a": @(1), @"b": @(2), @"c": @(3) };
    NSSet *set4 = [NSSet setWithArray:array1];
    NSString *string5 = @"hahaha";
    id val1 = [array1 vv_dbStoreValue];
    id val2 = [array2 vv_dbStoreValue];
    id val3 = [dic3 vv_dbStoreValue];
    id val4 = [set4 vv_dbStoreValue];
    id val5 = [string5 vv_dbStoreValue];
    if (val1 && val2 && val3 && val4 && val5) {
    }
}

//MARK: - FTS表
- (void)testMatch
{
    [self.ftsModel.vvdb.cache removeAllObjects];
    NSString *keyword = @"音乐舞";
    NSArray *array1 = [self.ftsModel match:@"industry".match(keyword) orderBy:nil limit:0 offset:0];
    NSArray *array2 = [self.ftsModel match:@"industry".match(keyword) groupBy:nil limit:0 offset:0];
    NSUInteger count = [self.ftsModel matchCount:@"industry".match(keyword)];
    VVSearchHighlighter *highlighter = [[VVSearchHighlighter alloc] initWithKeyword:keyword orm:self.ftsModel];
    highlighter.highlightAttributes = @{ NSForegroundColorAttributeName: [UIColor redColor] };
    NSArray *highlighted = [highlighter highlight:array1 field:@"industry"];
    if (array1 && array2 && count && highlighted) {
    }
}

- (void)testTokenizer
{
    VVTokenMask mask = VVTokenMaskAll;
    NSArray *texts = @[
        @"第二章",
        @"dez",
//        @"音乐123舞蹈",
//        @"13188886666",
//        @"234",
//        @"1,234,567,890",
//        @"12,345,678,901",
//        @"123,456,789,123",
//        @"jintiantianqizhenhao",
//        @"hello world",
//        @"饿了没",
//        @"chengke",
//        @"猛",
//        @"me",
    ];
    for (NSString *text in texts) {
        NSArray<VVToken *> *tokens = [VVTokenEnumerator enumerate:text method:VVTokenMethodSequelize mask:mask];
        NSLog(@"\n%@:\n%@", text, tokens);
    }
}

- (void)testTokenizer1
{
    VVTokenMask mask = VVTokenMaskDefault;
    NSArray *texts = @[
        @"陕西",
        @"西安",
        @"中国电信",
        @"中国移动",
        @"会计",
        @"体育运动",
        @"保健",
        @"保险业",
        @"健康",
        @"公益组织",
        @"军人",
        @"农业",
        @"出版",
        @"化学",
        @"医疗服务",
        @"司机",
        @"司法",
        @"咨询",
        @"因特网",
        @"培训",
        @"媒体",
        @"学术研究",
        @"宾馆",
        @"广告业",
        @"建筑业",
        @"律师",
        @"房地产",
        @"批发",
        @"政府机关",
        @"教育",
        @"旅游业",
        @"服务",
        @"服装业",
        @"木材",
        @"机械制造",
        @"消防",
        @"演艺",
        @"电讯业",
        @"美容",
        @"能源",
        @"航空航天",
        @"艺术",
        @"警察",
        @"计算机",
        @"设计",
        @"运输业",
        @"造纸",
        @"邮政快递",
        @"采矿",
        @"金属冶炼",
        @"金融",
        @"银行",
        @"零售",
        @"音乐舞蹈",
        @"餐饮"
    ];
    for (NSString *text in texts) {
        NSArray<VVToken *> *tokens = [VVTokenEnumerator enumerate:text method:VVTokenMethodSequelize mask:mask];
        if (tokens) {
        }
        //NSLog(@"%@:\n%@", text, tokens);
    }
}

- (void)testTokenizer2
{
    [VVTokenEnumerator registerEnumerator:VVTestEnumerator.class forMethod:VVTokenMethodTest];
    VVTokenMask mask = VVTokenMaskAll;
    NSArray *texts = @[
        @"第二章",
        @"dez",
        @"音乐123舞蹈",
        @"13188886666",
    ];
    for (NSString *text in texts) {
        NSArray<VVToken *> *tokens = [VVTokenEnumerator enumerate:text method:VVTokenMethodTest mask:mask];
        NSLog(@"\n%@:\n%@", text, tokens);
    }
}

- (void)testHighlight
{
    NSString *keyword = @"zhk";
    VVSearchHighlighter *highlighter = [[VVSearchHighlighter alloc] initWithKeyword:keyword];
    highlighter.options = VVMatchOptionsAll;
    highlighter.highlightAttributes = @{ NSForegroundColorAttributeName: [UIColor redColor] };
    VVResultMatch *match = [highlighter highlight:@"却迎来了一名不速之客"];
    if (match) {
    }
}

- (void)testTransform
{
    [self measureBlock:^{
        NSString *string = @"協力廠商研究公司Strategy" "Analytic曾於2月發佈數據預測，稱2020年AirPods出貨量有望增長50%，達到9000萬套。"
            "這也意味著AirPods 2019年銷量達到了6000萬套，但也有分析師認為其2019年實際出貨量並未達到這個水准。"
            " 蘋果不在財報中公佈AirPods的銷售數位，而是將其歸入“可穿戴設備、家庭用品和配件”類別。"
            " 上個季度，蘋果該類別創下了新的收入紀錄，蘋果將這歸功於Apple Watch和AirPods的成功。"
            "同樣在2月，天風國際分析師郭明錤給出了2020年度AirPods系列產品的預估出貨量，因受公共衛生事件影響，郭明錤預估AirPods系列產品在2020年出貨量約8000–9000萬部，其中AirPods Pro將會占到40%或更高的份額。"
            "稍早前，蘋果中國官網一度對包括iPhone、iPad、Airpods Pro在內的產品進行限購，但3天后又解除了大部分產品的購買限制，只有新款MacBook Air和iPad Pro仍維持限購措施。";
        NSString *simplified = string.simplifiedChineseString;
        NSString *traditional = simplified.traditionalChineseString;
        if (traditional) {}
    }];
}

- (void)testPinyin
{
    VVPinYinFruit *fruit = [@"广里给雨六只还尾" pinyinMatrix];
    if (fruit) {
    }
    //NSLog(@"fruit:\n%@\n%@", fruit.fulls, fruit.abbrs);
}

- (void)testSplit
{
    NSArray *pinyins = @[
        @"jintiantianqizhenhaoa",
        @"jintiantianqizhenhao",
        @"jintiantianqizhenha",
        @"jintiantianqizhenh",
        @"jintiantianqizhen",
        @"helloworld",
        @"jin,tian,tian,qi,zhen,hao,a",
        @"jin'tian'tian'qi'zhen'hao'a",
    ];
    for (NSString *pinyin in pinyins) {
        NSArray *array = [pinyin pinyinSegmentation];
        NSLog(@"%@", array);
    }
}

- (void)testTiledArray
{
    [self measureBlock:^{
        /*
         NSArray *array = @[
         @[@"11", @"12", @"13"],
         @[@"21", @"22", @"23"],
         @[@"31", @"32", @"33"],
         ];
         */
        NSArray *array = @[
            @[@"11", @"12", @"13", @"14", @"15", @"16", @"17"],
            @[@"21", @"22", @"23", @"24", @"25", @"26", @"27"],
            @[@"31", @"32", @"33", @"34", @"35", @"36", @"37"],
            @[@"41", @"42", @"43", @"44", @"45", @"46", @"47"],
            @[@"51", @"52", @"53", @"54", @"55", @"56", @"57"],
            @[@"61", @"62", @"63", @"64", @"65", @"66", @"67"],
            @[@"71", @"72", @"73", @"74", @"75", @"76", @"77"],
        ];
        [array tiledArray];
        /*
        NSArray *tiled = array.tiledArray;
        NSMutableString *string = [NSMutableString string];
        for (NSArray *sub in tiled) {
            for (NSString *obj in sub) {
                [string appendFormat:@"%@ ", obj];
            }
            [string appendFormat:@"\n"];
        }
        NSLog(@"\n%@", string);
         */
    }];
}

//MARK: - upgrader

- (void)testUpgrader
{
    VVDBUpgrader *upgrader = [[VVDBUpgrader alloc] init];
    [[NSUserDefaults standardUserDefaults] setObject:@"0.1.0" forKey:upgrader.versionKey];
    BOOL (^ handler)(VVDBUpgradeItem *) = ^(VVDBUpgradeItem *item) {
        NSLog(@"-> %@", item);
        for (NSInteger i = 1; i <= 10; i++) {
            item.progress = i * 10;
        }
        return YES;
    };
    VVDBUpgradeItem *item1 = [VVDBUpgradeItem itemWithIdentifier:@"1" version:@"0.1.1" stage:0 handler:handler];
    item1.weight = 5.0;
    VVDBUpgradeItem *item2 = [VVDBUpgradeItem itemWithIdentifier:@"2" version:@"0.1.4" stage:0 handler:handler];
    item2.weight = 2.0;
    VVDBUpgradeItem *item3 = [VVDBUpgradeItem itemWithIdentifier:@"3" version:@"0.1.1" stage:1 handler:handler];
    item3.weight = 3.0;
    VVDBUpgradeItem *item4 = [VVDBUpgradeItem itemWithIdentifier:@"4" version:@"0.1.3" stage:1 handler:handler];
    item4.weight = 10.0;
    VVDBUpgradeItem *item5 = [VVDBUpgradeItem itemWithIdentifier:@"5" version:@"0.1.2" stage:0 handler:handler];
    item5.weight = 3.0;

    [upgrader addItems:@[item1, item2, item3, item4, item5]];

    [upgrader.progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:nil];
    [upgrader upgradeAll];
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:100];
    [progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:nil];
    [upgrader debugUpgradeItems:@[item1, item2, item3] progress:progress];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context
{
    NSProgress *progress = object;
    NSLog(@"progress: %.2f%%", progress.fractionCompleted * 100.0);
}

@end
