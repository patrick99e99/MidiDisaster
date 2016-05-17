#import <Foundation/Foundation.h>
#import "NBAudioStream.h"
#import <OpenAL/al.h>
#import <OpenAL/alc.h>

@interface NBAudioStream ()
@property (nonatomic, strong) NSArray *bufferIDs;
@end

@implementation NBAudioStream {
    NSUInteger _bufferIndex;
    NSUInteger _numberOfBuffers;
    BOOL _isActive;
    float _sleepTime;
    ALuint _sourceID;
}

-(instancetype)init {
    if (self = [super init]) {
        [self createSource];
    }
    return self;
}

-(NSArray *)bufferIDs {
    if (!_bufferIDs) {
        _numberOfBuffers = [self numberOfBuffers];
        ALenum err;
        NSMutableArray *buffers = [NSMutableArray arrayWithCapacity:_numberOfBuffers];
        for (int i = 0; i < _numberOfBuffers; i++) {
            ALuint bufferID;
            alGenBuffers(1, &bufferID);
            err = alGetError();
            if (err != 0) NSLog(@"Error alGenBuffers! %i", err);

            [buffers addObject:[NSNumber numberWithUnsignedInteger:bufferID]];
        }

        _bufferIDs = [buffers copy];
    }
    return _bufferIDs;
}

-(NSUInteger)numberOfBuffers {
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

-(NSUInteger)bufferSize {
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

-(void)start {
    [self reset];

    if (_isActive) return;
    _isActive = YES;
    _sleepTime = 1.0f / ((float)[self sampleRate] / (float)[self bufferSize]);

    ALenum err;

    _bufferIndex = 0;

    for (NSNumber *bufferNumber in self.bufferIDs) {
        ALuint bufferID = [bufferNumber unsignedIntegerValue];
        [self fillBufferForBufferID:bufferID];
        alSourceQueueBuffers(_sourceID, 1, &bufferID);
        err = alGetError();
        if (err != 0) {
            NSLog(@"Error alSourceQueueBuffers! %i", err);
        }
    }
    
    alSourcePlay(_sourceID);
    
    err = alGetError();
    if (err != 0) {
        NSLog(@"Error playing stream! %i", err);
    } else {
        [NSThread detachNewThreadSelector:@selector(rotateBuffers) toTarget:self withObject:nil];
    }
}

-(void)stop {
    if (!_isActive) return;

    _isActive = NO;
    [NSThread cancelPreviousPerformRequestsWithTarget:self];
    
    alSourceStop(_sourceID);
    for (NSNumber *bufferNumber in self.bufferIDs) {
        ALuint bufferID = [bufferNumber unsignedIntegerValue];
        alSourceUnqueueBuffers(_sourceID, 1, &bufferID);
    }
}

-(void)createSource {
    ALenum err = alGetError();
    ALuint sourceID;
    alGenSources(1, &sourceID);
    
    alSourcei(sourceID, AL_BUFFER, 0);
    
    alSourcef(sourceID, AL_PITCH, 1.0f);
    err = alGetError();
    if (err != 0) NSLog(@"Error AL_PITCH! %i", err);
    
    alSourcef(sourceID, AL_GAIN, 1.0f);
    err = alGetError();
    if (err != 0) NSLog(@"Error AL_GAIN! %i", err);
    
    alSourcei(sourceID, AL_LOOPING, AL_FALSE);
    err = alGetError();
    if (err != 0) NSLog(@"Error AL_LOOPING! %i", err);
    
    _sourceID = sourceID;
}

-(NSUInteger)sampleRate {
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

-(void)fillBufferForBufferID:(NSUInteger)bufferID {
    short *buffer;
    NSUInteger size = [self bufferSize] * 2;
    buffer = (short *)malloc(size);
    [self fillBuffer:buffer bufferSize:[self bufferSize]];

    alBufferData(bufferID, AL_FORMAT_MONO16, buffer, size, [self sampleRate]);
    
    ALenum err = alGetError();
    if (err != 0) NSLog(@"Error streaming buffer %i", err);
    
    free(buffer);

    if (_bufferIndex == _numberOfBuffers - 1) {
        _bufferIndex = 0;
    } else {
        _bufferIndex += 1;
    }
}

-(BOOL)isActive {
    return _isActive;
}

-(void)rotateBuffers {
    while (_isActive) {
        @autoreleasepool {
            ALint buffersProcessed = 0;
            alGetSourcei(_sourceID, AL_BUFFERS_PROCESSED, &buffersProcessed);
            
            while (buffersProcessed) {
                if (!_isActive) return;

                ALuint bufferID;
                alSourceUnqueueBuffers(_sourceID, 1, &bufferID);
                [self fillBufferForBufferID:bufferID];

                alSourceQueueBuffers(_sourceID, 1, &bufferID);
                
                buffersProcessed -= 1;
            }
            
            ALint state = 0;
            
            alGetSourcei(_sourceID, AL_SOURCE_STATE, &state);
            if (state != AL_PLAYING) alSourcePlay(_sourceID);
            
            [NSThread sleepForTimeInterval:_sleepTime];
        }
    }
}

-(void)fillBuffer:(short *)buffer bufferSize:(NSUInteger)bufferSize {
    [self doesNotRecognizeSelector:_cmd];
}

-(void)reset {}

@end

