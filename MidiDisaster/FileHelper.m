#import "FileHelper.h"

@implementation FileHelper

+(NSDictionary *)dictionaryForFilesWithExtension:(NSString *)extension {
    return [self dictionaryForFilesWithExtension:extension evaluator:^(NSData *data) {
        return data;
    }];
}

+(NSDictionary *)dictionaryForFilesWithExtension:(NSString *)extension evaluator:(id (^)(NSData *data))evaluator {
    NSArray *files = [[NSBundle mainBundle] pathsForResourcesOfType:extension
                                                        inDirectory:nil];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[files count]];

    for (NSString *file in files) {
        NSString *key = [self keyForFile:file];
        NSData *data = [NSData dataWithContentsOfFile:file];
        [dictionary setObject:evaluator(data) forKey:key];
    }

    return [dictionary copy];
}

+(NSString *)keyForFile:(NSString *)file {
    NSString *fileName = [[file componentsSeparatedByString:@"/"] lastObject];
    return [[[fileName componentsSeparatedByString:@"."] firstObject] lowercaseString];
}

@end
