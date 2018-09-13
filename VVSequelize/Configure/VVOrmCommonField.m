//
//  VVOrmCommonField.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmCommonField.h"

@implementation VVOrmCommonField

+ (instancetype)fieldWithDictionary:(NSDictionary *)dictionary{
    NSString *name = dictionary[@"name"];
    if(!name || name.length == 0) return nil;
    VVOrmCommonField *field = [[VVOrmCommonField alloc] initWithName:name
                                                                  pk:[dictionary[@"pk"] integerValue]
                                                             notnull:[dictionary[@"notnull"] boolValue]
                                                              unique:[dictionary[@"unique"] boolValue]
                                                             indexed:[dictionary[@"indexed"] boolValue]
                                                          dflt_value:dictionary[@"dflt_value"]];
    field.type  = dictionary[@"type"];
    return field;
}

- (instancetype)initWithName:(NSString *)name
                          pk:(VVOrmPkType)pk
                     notnull:(BOOL)notnull
                      unique:(BOOL)unique
                     indexed:(BOOL)indexed
                  dflt_value:(NSString *)dflt_value
{
    self = [super init];
    if (self) {
        self.name       = name;
        self.pk         = pk;
        self.notnull    = notnull;
        self.unique     = self.pk ? YES : unique;
        self.dflt_value = !dflt_value || [dflt_value isKindOfClass:NSNull.class] ? nil : [NSString stringWithFormat:@"%@",dflt_value];
        self.indexed    = (!self.pk && self.unique) ? YES : indexed;
    }
    return self;
}

- (BOOL)isEqualToField:(VVOrmField *)field{
    if(![field isKindOfClass:VVOrmCommonField.class]) return NO;
    VVOrmCommonField *f1 = (VVOrmCommonField *)self;
    VVOrmCommonField *f2 = (VVOrmCommonField *)field;
    return [f1.name isEqualToString:f2.name]
    && [f1.type.uppercaseString isEqualToString:f2.type.uppercaseString]
    && [f1.dflt_value isEqualToString:f2.dflt_value]
    && f1.pk      == f2.pk
    && f1.notnull == f2.notnull
    && f1.unique  == f2.unique;
}

@end