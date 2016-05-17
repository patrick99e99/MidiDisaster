#import "FMInstrument.h"
#import "synth_unit.h"
#import "ringbuffer.h"
#include <mach/mach.h>
#include <mach/mach_time.h>

@interface FMInstrument ()

@property (nonatomic) MIDITimeStamp lastReadAt;
@property (nonatomic, strong) NSMutableArray *deltas;

@end


double convertToSeconds(MIDITimeStamp timestmap) {
    double kOneMillion = 1000.0f * 1000.0f;
    static mach_timebase_info_data_t s_timebase_info;
    
    if (s_timebase_info.denom == 0) {
        (void) mach_timebase_info(&s_timebase_info);
    }
    
    // mach_absolute_time() returns billionth of seconds,
    // so divide by one million to get milliseconds
    return (double)timestmap * (double)s_timebase_info.numer / (kOneMillion * (double)s_timebase_info.denom) * 0.001f;
}

@implementation FMInstrument {
    SynthUnit *_synthUnit;
    RingBuffer *_ringBuffer;
    short *_generatedSamples;
    int _bufferReadIndex;
    int _bufferWriteIndex;
    int _maxBufferIndex;
    double _nanoSecondsToSeconds;
}

+(void)initializeFMSynthUnit {
    SynthUnit::Init([self sampleRate]);
}

+(NSUInteger)sampleRate {
    return 44100;
}

-(instancetype)init {
    if (self = [super init]) {
        _ringBuffer       = new RingBuffer();
        _synthUnit        = new SynthUnit(_ringBuffer);
        _maxBufferIndex   = (int)([self sampleRate] * 45) - 1;
        _generatedSamples = (short *)calloc(_maxBufferIndex + 1, sizeof(short));
        _bufferReadIndex  = 0;
        _bufferWriteIndex = 0;
        
        mach_timebase_info_data_t sTimebaseInfo;
        mach_timebase_info(&sTimebaseInfo);
        
        _nanoSecondsToSeconds = sTimebaseInfo.numer / sTimebaseInfo.denom / 1000000000.0;
        
        [NSThread detachNewThreadSelector:@selector(startPolling) toTarget:self withObject:nil];
    }
    return self;
}

-(void)setTrackNumber:(NSUInteger)trackNumber {
    _synthUnit->SetTrackNumber((int)trackNumber);
}

-(void)startPolling {
    while (![self isActive]) {
        @autoreleasepool {
            if (![self.deltas count]) continue;
            
            int numberOfSamplesToGenerate = ceil([self sampleRate] * [[self.deltas lastObject] doubleValue]);
            [self.deltas removeLastObject];
            short *tempBuffer = (short *)malloc(sizeof(short) * numberOfSamplesToGenerate);
            _synthUnit->GetSamples(numberOfSamplesToGenerate, tempBuffer);
            
            for (int i = 0; i < numberOfSamplesToGenerate; i++) {
                _generatedSamples[_bufferWriteIndex] = tempBuffer[i];
                _bufferWriteIndex += 1;
                if (_bufferWriteIndex > _maxBufferIndex) _bufferWriteIndex = 0;
            }
            free(tempBuffer);
        }
    }
}

-(instancetype)initWitHSysex:(NSData *)sysex {
    if (self = [self init]) {
        [self loadSysex:sysex];
    }
    return self;
}

-(NSUInteger)bufferSize {
    return 1024;
}

-(NSUInteger)numberOfBuffers {
    return 16;
}

-(NSUInteger)sampleRate {
    return [[self class] sampleRate];
}

-(void)dealloc {
    delete _synthUnit;
    delete _ringBuffer;
    free(_generatedSamples);
}

-(NSMutableArray *)deltas {
    if (!_deltas) {
        _deltas = [NSMutableArray arrayWithCapacity:512];
    }
    return _deltas;
}

-(void)fillBuffer:(short *)buffer bufferSize:(NSUInteger)bufferSize {
    for (int i = 0; i < bufferSize; i++) {
        buffer[i] = _generatedSamples[_bufferReadIndex];
        _bufferReadIndex += 1;
        if (_bufferReadIndex >= _maxBufferIndex) _bufferReadIndex = 0;
    }
}

-(void)loadSysex:(NSData *)data {
    unsigned char *buffer = (unsigned char*)[data bytes];
    _ringBuffer->Write(buffer, 4104);
}

-(void)writePacketWithObservedTimestamps:(MIDIPacket)packet {
    _ringBuffer->Write(packet.data, packet.length);
    MIDITimeStamp now = packet.timeStamp;
    if (self.lastReadAt) {
        NSNumber *delta = [NSNumber numberWithDouble:convertToSeconds(now) - convertToSeconds(self.lastReadAt)];
        [self.deltas insertObject:delta atIndex:0];
    }
    self.lastReadAt = now;
}

@end
