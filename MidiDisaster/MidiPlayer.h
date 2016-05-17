#import <Foundation/Foundation.h>

@interface MidiPlayer : NSObject

-(void)playMidi:(NSData *)midi cartridge:(NSString *)cartridge;
-(void)stop;

@end
