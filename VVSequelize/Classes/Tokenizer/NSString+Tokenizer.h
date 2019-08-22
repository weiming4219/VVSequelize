//
//  NSString+Tokenizer.h
//  VVSequelize
//
//  Created by Valo on 2019/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Tokenizer)

/**
 拼音分词资源预加载
 */
+ (void)preloadingForPinyin;

/**
 设置生成多音字拼音的最大长度,默认为5

 @param maxSupportLength 最大中文长度
 */
+ (void)setMaxSupportLengthOfPolyphone:(NSUInteger)maxSupportLength;

/**
 将字符串中的繁体中文转换成简体中文

 @return 简体中文字符串
 */
- (NSString *)simplifiedChineseString;

/**
 将字符串中的简体中文转换成繁体中文

 @return 繁体中文字符串
 */
- (NSString *)traditionalChineseString;

/**
 判断字符串是否含有中文

 @note 不建议在分词步骤中判断是否含中文,正则表达式效率较低.
 @return 是否含有中文
 */
- (BOOL)hasChinese;

/**
 获取字符串的中文拼音

 @return 中文拼音字符串,不含空格
 */
- (NSString *)pinyin;

/**
 获取字符串的拼音分词数据

 @return 中文拼音字符串数组
 */
- (NSArray<NSString *> *)pinyinsForTokenize;

/**
 获取字符串的数字分词数据

 @return 数字分词数组
 */
- (NSArray<NSString *> *)numberStringsForTokenize;

/**
 去除掉各种特殊字符之后的干净字符串

 @return 干净字符串
 */
- (NSString *)clearString;

@end

NS_ASSUME_NONNULL_END
