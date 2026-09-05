#import "OMGGenerator.h"
#include <stdint.h>
#include <stdlib.h>

static NSString * const CursorKey = @"originalMotivationGenerator.v1.cursor";
static NSString * const OffsetKey = @"originalMotivationGenerator.v1.offset";
static NSString * const PhraseKey = @"originalMotivationGenerator.v1.lastPhrase";

@implementation OMGGenerator
+ (NSString *)lastPhrase {
    return [[NSUserDefaults standardUserDefaults] stringForKey:PhraseKey];
}

+ (NSString *)nextPhrase {
    static NSDictionary *pools;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Words" ofType:@"plist"];
        pools = [NSDictionary dictionaryWithContentsOfFile:path];
    });
    NSArray *verbs = [pools objectForKey:@"verbs"];
    NSArray *adjectives = [pools objectForKey:@"adjectives"];
    NSArray *nouns = [pools objectForKey:@"nouns"];
    if (verbs.count != 225 || adjectives.count != 225 || nouns.count != 225) {
        return @"词库加载失败";
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    const int64_t total = 11390625;
    int64_t cursor = [defaults integerForKey:CursorKey];
    if (cursor < 0 || cursor > total) return @"生成进度异常";
    if (cursor == total) return nil;
    NSNumber *storedOffset = [defaults objectForKey:OffsetKey];
    int64_t offset;
    if (!storedOffset) {
        offset = arc4random_uniform((uint32_t)total);
        [defaults setObject:@(offset) forKey:OffsetKey];
    } else {
        offset = [storedOffset longLongValue];
        if (offset < 0 || offset >= total) return @"生成进度异常";
    }
    // The multiplication exceeds INT32_MAX on armv7; keep all arithmetic 64-bit.
    int64_t combination = (cursor * INT64_C(104729) + offset) % total;
    NSString *phrase = [NSString stringWithFormat:@"%@%@的%@",
        [verbs objectAtIndex:(NSUInteger)(combination % 225)],
        [adjectives objectAtIndex:(NSUInteger)((combination / 225) % 225)],
        [nouns objectAtIndex:(NSUInteger)(combination / 50625)]];
    [defaults setInteger:(NSInteger)(cursor + 1) forKey:CursorKey];
    [defaults setObject:phrase forKey:PhraseKey];
    return phrase;
}
@end
