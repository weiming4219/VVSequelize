//
//  VVFtsHighlighter.m
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import "VVSearchHighlighter.h"
#import "VVDatabase+FTS.h"
#import "NSString+Tokenizer.h"

#define _VVMatchPinyinLen 30

@interface VVResultMatch ()
@property (nonatomic, assign) VVMatchLV1 lv1;
@property (nonatomic, assign) VVMatchLV2 lv2;
@property (nonatomic, assign) VVMatchLV3 lv3;
@end

@implementation VVResultMatch
@synthesize lowerWeight = _lowerWeight;
@synthesize upperWeight = _upperWeight;
@synthesize weight = _weight;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _range = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (UInt64)upperWeight
{
    if (_upperWeight == 0 && _range.length > 0) {
        _upperWeight = (UInt64)(_lv1 & 0xF) << 28 | (UInt64)(_lv2 & 0xF) << 24 | (UInt64)(_lv3 & 0xF) << 20;
    }
    return _upperWeight;
}

- (UInt64)lowerWeight
{
    if (_upperWeight == 0 && _range.length > 0) {
        UInt64 loc = ~_range.location & 0xFFFF;
        UInt64 rate = ((UInt64)_range.length << 32) / _source.length;
        _lowerWeight = (UInt64)(loc & 0xFFFF) << 16 | (UInt64)(rate & 0xFFFF) << 0;
    }
    return _upperWeight;
}

- (UInt64)weight
{
    if (_weight == 0 && _range.length > 0) {
        _weight = self.upperWeight << 32 | self.lowerWeight;
    }
    return _weight;
}

- (NSComparisonResult)compare:(VVResultMatch *)other
{
    return self.weight == other.weight ? NSOrderedSame : self.weight > other.weight ? NSOrderedAscending : NSOrderedDescending;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@|%@|%@|%@]: 0x%llX", @(_lv1), @(_lv2), @(_lv3), NSStringFromRange(_range), self.weight];
}

@end

@interface VVSearchHighlighter ()
@property (nonatomic, strong) NSArray<VVToken *> *keywordTokens;
@property (nonatomic, strong) NSString *keywordFullPinyin;
@end

@implementation VVSearchHighlighter

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithKeyword:(NSString *)keyword
{
    self = [super init];
    if (self) {
        [self setup];
        _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return self;
}

- (instancetype)initWithKeyword:(NSString *)keyword orm:(VVOrm *)orm
{
    self = [super init];
    if (self) {
        NSAssert(orm.config.fts && orm.config.ftsTokenizer.length > 0, @"Invalid fts orm!");
        [self setup];
        NSString *tokenizer = [orm.config.ftsTokenizer componentsSeparatedByString:@" "].firstObject;
        _method = [orm.vvdb methodForTokenizer:tokenizer];
        _options = VVMatchOptionPinyin | VVMatchOptionToken;
        _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return self;
}

- (void)setup {
    _options = VVMatchOptionPinyin;
    _method = VVTokenMethodSequelize;
    _mask = VVTokenMaskDeault;
    _attrTextMaxLength = 17;
}

- (void)setKeyword:(NSString *)keyword {
    _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSArray<VVToken *> *)keywordTokens {
    if (!_keywordTokens) {
        NSAssert(_keyword.length > 0, @"Invalid keyword");
        VVTokenMask mask = _mask | _VVMatchPinyinLen;
        _keywordTokens = [VVTokenEnumerator enumerate:_keyword method:_method mask:mask];
    }
    return _keywordTokens;
}

- (NSDictionary<NSAttributedStringKey, id> *)normalAttributes {
    if (!_normalAttributes) {
        _normalAttributes = @{};
    }
    return _normalAttributes;
}

- (NSDictionary<NSAttributedStringKey, id> *)highlightAttributes {
    if (!_highlightAttributes) {
        _highlightAttributes = @{};
    }
    return _highlightAttributes;
}

- (NSString *)keywordFullPinyin {
    if (!_keywordFullPinyin) {
        if (_keyword.length > _VVMatchPinyinLen) {
            _keywordFullPinyin = @"";
        } else {
            NSString *keyword = _keyword.lowercaseString;
            if (_mask & VVTokenMaskTransform) {
                keyword = keyword.simplifiedChineseString;
            }
            _keywordFullPinyin = [[keyword pinyin] stringByReplacingOccurrencesOfString:@" " withString:@""];
        }
    }
    return _keywordFullPinyin;
}

//MARK: - highlight search result
- (NSArray<VVResultMatch *> *)highlight:(NSArray<NSObject *> *)objects field:(NSString *)field
{
    NSAssert(_keyword.length > 0 && field.length > 0, @"Invalid highlight parameters");
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objects.count];
    for (NSObject *object in objects) {
        NSString *source = [object valueForKey:field];
        BOOL valid = [source isKindOfClass:NSString.class] && source.length > 0;
        if (!valid) source = @"";
        VVResultMatch *match = [self highlight:source];
        [results addObject:match];
    }
    return results;
}

- (VVResultMatch *)highlight:(NSString *)source
{
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.source = source;
    if (source.length == 0) return match;

    NSString *clean = [source stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *comparison = clean.lowercaseString;
    if (self.mask & VVTokenMaskTransform) {
        comparison = comparison.simplifiedChineseString;
    }
    const char *cleanText = clean.cString;
    const char *pText = comparison.cString;
    int nText = (int)strlen(pText);
    if (nText == 0) return match;

    NSString *keyword = _keyword.lowercaseString;
    if (self.mask & VVTokenMaskTransform) {
        keyword = keyword.simplifiedChineseString;
    }

    match = [self highlight:source keyword:keyword lv1:VVMatchLV1_Origin
                      clean:clean comparison:comparison cleanText:cleanText pText:pText];
    BOOL fuzzy = (self.options & VVMatchOptionPinyin) && (self.options & VVMatchOptionFuzzy);
    if (match.upperWeight == 0 && fuzzy) {
        VVResultMatch *otherMatch = nil;
        if (self.keywordFullPinyin.length > 0 && ![self.keywordFullPinyin isEqualToString:self.keyword]) {
            otherMatch = [self highlight:source keyword:self.keywordFullPinyin lv1:VVMatchLV1_Fulls
                                   clean:clean comparison:comparison cleanText:cleanText pText:pText];
            if (otherMatch.upperWeight > 0) return otherMatch;
        }
    }
    return match;
}

- (NSAttributedString *)highlightText:(NSString *)clean WithRange:(NSRange)range
{
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];
    NSUInteger lower = range.location;
    NSUInteger upper = NSMaxRange(range);
    NSUInteger len = range.length;
    NSUInteger maxLen = self.attrTextMaxLength;

    NSString *s1 = [clean substringToIndex:lower] ? : @"";
    NSString *sk = [clean substringWithRange:range] ? : @"";
    NSString *s2 = [clean substringFromIndex:upper] ? : @"";
    NSAttributedString *a1 = [[NSAttributedString alloc] initWithString:s1 attributes:self.normalAttributes];
    NSAttributedString *ak = [[NSAttributedString alloc] initWithString:sk attributes:self.highlightAttributes];
    NSAttributedString *a2 = [[NSAttributedString alloc] initWithString:s2 attributes:self.normalAttributes];
    [attrText appendAttributedString:a1];
    [attrText appendAttributedString:ak];
    [attrText appendAttributedString:a2];

    if (upper > maxLen && lower > 2) {
        NSInteger rlen = (2 + len > maxLen) ? (lower - 2) : (upper - maxLen);
        [attrText deleteCharactersInRange:NSMakeRange(0, rlen)];
        NSAttributedString *ellipsis = [[NSAttributedString alloc] initWithString:@"..."];
        [attrText insertAttributedString:ellipsis atIndex:0];
    }
    return attrText;
}

- (VVResultMatch *)highlight:(NSString *)source keyword:(NSString *)keyword lv1:(VVMatchLV1)lv1
                       clean:(NSString *)clean comparison:(NSString *)comparison
                   cleanText:(const char *)cleanText pText:(const char *)pText
{
    VVResultMatch *nomatch = [[VVResultMatch alloc] init];
    nomatch.source = source;

    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.lv1 = lv1;
    match.source = source;
    int nText = (int)strlen(pText);

    BOOL hasSpace = [keyword rangeOfString:@" "].length > 0;
    NSString *exp = hasSpace ? [keyword stringByReplacingOccurrencesOfString:@" +" withString:@" +" options:NSRegularExpressionSearch range:NSMakeRange(0, keyword.length)] : keyword;
    NSRange found = hasSpace ? [comparison rangeOfString:exp options:NSRegularExpressionSearch] : [comparison rangeOfString:keyword];
    if (found.location == 0 && found.length == source.length) {
        match.lv2 = VVMatchLV2_Full;
        match.range = found;
    } else if (found.location == 0 && found.length < source.length) {
        match.lv2 = VVMatchLV2_Prefix;
        match.range = found;
    } else if (found.location != NSNotFound && found.length > 0) {
        match.lv2 = VVMatchLV2_NonPrefix;
        match.range = found;
    }

    if (match.lv2 != VVMatchLV2_None) {
        match.lv3 = lv1 == VVMatchLV1_Origin ? VVMatchLV3_High : VVMatchLV3_Medium;
        match.attrText = [self highlightText:clean WithRange:found];
        return match;
    }

    if (self.options & VVMatchOptionPinyin) {
        VVPinYinFruit *fruit = [comparison pinyinMatrix];
        NSArray<NSArray<NSString *> *> *matrixes = @[(lv1 == VVMatchLV1_Origin ? fruit.abbrs : @[]), fruit.fulls];
        for (NSInteger i = 0; i < matrixes.count; i++) {
            NSArray *matrix = matrixes[i];
            for (NSArray *pinyins in matrix) {
                NSString *py = [pinyins componentsJoinedByString:@""];
                found = hasSpace ? [py rangeOfString:exp options:NSRegularExpressionSearch] : [py rangeOfString:keyword];
                if (found.length > 0) {
                    VVMatchLV2 lv2 = VVMatchLV2_None;
                    if (found.location == 0 && found.length == py.length) {
                        lv2 = keyword.length == 1 ? VVMatchLV2_Prefix : VVMatchLV2_Full;
                    } else if (found.location == 0 && found.length < py.length) {
                        lv2 = VVMatchLV2_Prefix;
                    } else {
                        lv2 = VVMatchLV2_NonPrefix;
                    }
                    if ((lv2 > match.lv2) || (lv2 == match.lv2 && (found.location < match.range.location || i == 1) )) {
                        NSUInteger offset = 0, idx = 0;
                        while (offset < found.location && idx < pinyins.count) {
                            NSString *s = pinyins[idx];
                            offset += s.length;
                            idx++;
                        }
                        BOOL valid = offset == found.location;

                        if (valid) {
                            idx = idx >= pinyins.count ? pinyins.count - 1 : idx;
                            NSUInteger hloc = idx, mlen = 0;
                            while (mlen < found.length && idx < pinyins.count) {
                                NSString *s = pinyins[idx];
                                mlen += s.length;
                                idx++;
                            }
                            valid = mlen == found.length;
                            if (valid) {
                                NSUInteger hlen = idx - hloc;
                                NSRange hlRange = NSMakeRange(hloc, hlen);

                                match.lv2 = lv2;
                                match.range = found;
                                match.lv3 = (i == 1) ? VVMatchLV3_Medium : VVMatchLV3_Low;
                                match.attrText = [self highlightText:clean WithRange:hlRange];
                            }
                        }
                    }
                }
                if (match.lv2 == VVMatchLV2_Full) break;
            }
            if (match.lv2 == VVMatchLV2_Full) break;
        }
    }
    if (match.lv2 != VVMatchLV2_None) {
        return match;
    }

    if (!(self.options & VVMatchOptionToken)) {
        return nomatch;
    }

    __block uint8_t *tokenized = (uint8_t *)malloc(nText + 1);
    memset(tokenized, 0x0, nText + 1);

    NSArray<VVToken *> *tokens = [VVTokenEnumerator enumerateCString:pText method:self.method mask:self.mask];

    unsigned long count = tokens.count;
    unsigned long kwcount = self.keywordTokens.count;

    unsigned long k = 0;
    for (unsigned long j = 0; j < kwcount; j++) {
        VVToken *kwToken = self.keywordTokens[j];
        for (unsigned long i = k; i < count; i++) {
            VVToken *token = tokens[i];
            if (strcmp(token.token.cString, kwToken.token.cString) != 0) continue;
            memcpy(tokenized + token.start, cleanText + token.start, token.end - token.start);
            k = i + 1;
            break;
        }
    }

    uint8_t *remained = (uint8_t *)malloc(nText + 1);
    memcpy(remained, cleanText, nText);
    remained[nText] = 0x0;
    for (int i = 0; i < nText + 1; i++) {
        if (tokenized[i] != 0) {
            memset(remained + i, 0x0, 1);
        }
    }

    int pos = 0, spos = 0, matchflag = -1;
    NSRange range = NSMakeRange(NSNotFound, 0);
    NSUInteger textLoc = 0;
    while (pos < nText + 1) {
        int curflag = tokenized[pos] == 0x0 ? 0 : 1;
        if (matchflag != curflag || pos == nText) {
            int len = pos - spos;
            if (len > 0) {
                uint8_t *bytes = (matchflag ? tokenized : remained) + spos;
                NSString *str = [[NSString alloc] initWithBytes:bytes length:len encoding:NSUTF8StringEncoding] ? : @"";
                if (matchflag == 1 && range.location == NSNotFound) {
                    range = NSMakeRange(textLoc, str.length);
                    break;
                }
                textLoc += str.length;
            }
            spos = pos;
            matchflag = curflag;
        }
        pos++;
    }
    free(remained);
    free(tokenized);

    if (range.length > 0) {
        match.range = range;
        match.attrText = [self highlightText:clean WithRange:range];
        if (match.lv2 == VVMatchLV2_None) {
            match.lv2 = VVMatchLV2_Other;
            match.lv3 = VVMatchLV3_Low;
        }
    } else {
        match.attrText = [[NSAttributedString alloc] initWithString:source attributes:self.normalAttributes];
    }

    return match.lv2 == VVMatchLV2_None ? nomatch : match;
}

@end
