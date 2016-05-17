#import <Foundation/Foundation.h>

@interface FileHelper : NSObject

+(NSDictionary *)dictionaryForFilesWithExtension:(NSString *)extension evaluator:(id (^)(NSData *data))evaluator;
+(NSDictionary *)dictionaryForFilesWithExtension:(NSString *)extension;

@end
