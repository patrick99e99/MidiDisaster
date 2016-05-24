#import "FMInstrument.h"
#import "synth_unit.h"
#import "ringbuffer.h"
#include <mach/mach.h>
#include <mach/mach_time.h>

@interface FMInstrument ()

@property (nonatomic) MIDITimeStamp lastReadAt;

@end

@implementation FMInstrument {
    SynthUnit *_synthUnit;
    RingBuffer *_ringBuffer;
    short *_generatedSamples;
    MIDIPacket *_midiPackets;
    MIDIPacket _lastMidiPacket;
    int _bufferReadIndex;
    int _bufferWriteIndex;
    int _maxBufferIndex;
    int _midiPacketReadIndex;
    int _midiPacketWriteIndex;
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
        _midiPackets      = (MIDIPacket *)calloc(1024, sizeof(MIDIPacket));
        _bufferReadIndex  = 0;
        _bufferWriteIndex = 0;
        _midiPacketReadIndex  = 0;
        _midiPacketWriteIndex = 0;
        _lastMidiPacket       = {0};
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
            if (_midiPacketWriteIndex <= _midiPacketReadIndex) continue;
            MIDIPacket midiPacket     = _midiPackets[_midiPacketReadIndex];
            MIDIPacket lastMidiPacket = _lastMidiPacket;

            _ringBuffer->Write(midiPacket.data, midiPacket.length);
            BOOL isFirstEvent = !_lastMidiPacket.timeStamp;
            _lastMidiPacket = midiPacket;
            if (isFirstEvent) continue;

            _midiPacketReadIndex += 1;
            double delta = (midiPacket.timeStamp * _nanoSecondsToSeconds) - (lastMidiPacket.timeStamp *_nanoSecondsToSeconds);

            int numberOfSamplesToGenerate = ceil([self sampleRate] * delta);
            short *tempBuffer = (short *)malloc(sizeof(short) * numberOfSamplesToGenerate);
            _synthUnit->GetSamples(numberOfSamplesToGenerate, tempBuffer);

            for (int i = 0; i < numberOfSamplesToGenerate && _bufferWriteIndex <= _maxBufferIndex; i++) {
                _generatedSamples[_bufferWriteIndex] = tempBuffer[i];
                _bufferWriteIndex += 1;
            }

            free(tempBuffer);
            [NSThread sleepForTimeInterval:0.05f];
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

-(void)generateSamplesForDuration:(double)duration {
    int numberOfSamplesToGenerate = [self sampleRate] * duration;
    short *tempBuffer = (short *)malloc(sizeof(short) * numberOfSamplesToGenerate);
    _synthUnit->GetSamples(numberOfSamplesToGenerate, tempBuffer);
    
    for (int i = 0; i < numberOfSamplesToGenerate; i++) {
        _generatedSamples[_bufferWriteIndex] = tempBuffer[i];
        _bufferWriteIndex += 1;
        if (_bufferWriteIndex > _maxBufferIndex) _bufferWriteIndex = 0;
    }
    free(tempBuffer);
}

-(void)writeMidiNote:(int)midiNote velocity:(int)velocity {
    MIDIPacket packet = [self packetWith:0x90 dataByte1:velocity dataByte2:0];
    _ringBuffer->Write(packet.data, packet.length);
}

-(void)enqueueMidiPacket:(MIDIPacket)packet {
    _midiPackets[_midiPacketWriteIndex] = packet;
    _midiPacketWriteIndex += 1;
}

-(MIDIPacket)packetWith:(char)command dataByte1:(char)dataByte1 dataByte2:(char)dataByte2 {
    MIDIPacket packet;
    packet.data[0] = command;
    packet.data[1] = dataByte1;
    packet.data[2] = dataByte2;
    packet.length = 3;
    return packet;
}


@end
