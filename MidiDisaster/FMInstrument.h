#import "NBAudioStream.h"
#import <Foundation/Foundation.h>
#import <CoreMidi/CoreMidi.h>

static float const MAX_FM_INSTRUMENT_VELOCITY = 128.0f;

@interface FMInstrument : NBAudioStream

+(void)initializeFMSynthUnit;
+(NSUInteger)sampleRate;
-(instancetype)initWitHSysex:(NSData *)sysex;
-(void)enqueueMidiPacket:(MIDIPacket)packet;
-(void)writeMidiNote:(int)midiNote velocity:(int)velocity;
-(void)generateSamplesForDuration:(double)duration;
-(void)setTrackNumber:(NSUInteger)trackNumber;

@end
