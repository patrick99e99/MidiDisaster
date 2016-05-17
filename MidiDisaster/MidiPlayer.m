#import "MidiPlayer.h"
#import <AudioToolbox/MusicPlayer.h>
#import "FMInstrument.h"
#import "FileHelper.h"

static const NSUInteger MIDI_PLAYER_MAXIMIUM_TRACKS = 16;

@interface MidiPlayer ()
@property (nonatomic, strong) NSArray *fmInstruments;
@property (nonatomic, strong) NSDictionary *sysexTable;
@end

typedef struct MidiData {
    __unsafe_unretained FMInstrument *fmInstruments[MIDI_PLAYER_MAXIMIUM_TRACKS];
} MidiData;

static void midiReadProc(const MIDIPacketList *pktlist,
                         void *refCon,
                         void *connRefCon) {
    
    struct MidiData *midiData = (struct MidiData *)refCon;

    MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
    for (int i = 0; i < pktlist->numPackets; i++) {
        NSUInteger channel = packet->data[0] & 0xf;
        FMInstrument *fmInstrument = midiData->fmInstruments[channel];
        if (fmInstrument) [fmInstrument writePacketWithObservedTimestamps:*packet];
        packet = MIDIPacketNext(packet);
    }
}

@implementation MidiPlayer {
    MusicSequence sequence;
    MusicPlayer player;
    MidiData midiData;
}

-(instancetype)init {
    if (self = [super init]) {
        [FMInstrument initializeFMSynthUnit];
    }
    return self;
}

-(NSDictionary *)sysexTable {
    if (!_sysexTable) {
        _sysexTable = [FileHelper dictionaryForFilesWithExtension:@"syx"];
    }
    return _sysexTable;
}

-(void)playMidi:(NSData *)midi cartridge:(NSString *)cartridge {
    [self stop];

    OSStatus result = noErr;
    MIDIClientRef virtualMidi;
    result = MIDIClientCreate(CFSTR("client"),
                              NULL,
                              NULL,
                              &virtualMidi);

    NSAssert(result == noErr, @"MIDIClientCreate failed. Error code: %d", (int)result);

    sequence = 0;
    player   = 0;

    NewMusicSequence(&sequence);
    MusicSequenceFileLoadData(sequence, (__bridge CFDataRef)midi, 0, 0);

    UInt32 numberOfChannels = 0;
    MusicSequenceGetTrackCount(sequence, &numberOfChannels);

    self.fmInstruments = [self createFMInstrumentsWith:cartridge numberOfChannels:numberOfChannels];
    struct MidiData initialized = {0};
    midiData = initialized;

    for (int i = 0; i < MIDI_PLAYER_MAXIMIUM_TRACKS; i++) {
        if (i < numberOfChannels) {
            midiData.fmInstruments[i] = [self.fmInstruments objectAtIndex:i];
        } else {
            midiData.fmInstruments[i] = nil;
        }
    }

    MIDIEndpointRef virtualEndpoint;
    result = MIDIDestinationCreate(virtualMidi, CFSTR("destination"), midiReadProc, &midiData, &virtualEndpoint);

    NSAssert(result == noErr, @"MIDIDestinationCreate failed. Error code: %d", (int)result);

    MusicSequenceSetMIDIEndpoint(sequence, virtualEndpoint);
    NewMusicPlayer(&player);
    MusicPlayerSetSequence(player, sequence);
    MusicPlayerPreroll(player);
    MusicPlayerStart(player); // start rendering to the proc, and send midi packets to the fm instruments
    
    MusicTrack time;
    MusicTimeStamp length;
    UInt32 size = sizeof(MusicTimeStamp);
    MusicSequenceGetIndTrack(sequence, 1, &time);
    MusicTrackGetProperty(time, kSequenceTrackProperty_TrackLength, &length, &size);

    while (1) { // wait until everything has been rendered
        usleep (3 * 1000000);
        MusicTimeStamp now = 0;
        MusicPlayerGetTime (player, &now);
        if (now >= length) break;
    }
    
    NSLog(@"starting FM");
    for (FMInstrument *inst in self.fmInstruments) {
        [inst start];
    }
}

-(void)stop {
    MusicPlayerStop(player);
    DisposeMusicSequence(sequence);
    DisposeMusicPlayer(player);
    
    for (FMInstrument *fmInstrument in self.fmInstruments) {
        [fmInstrument stop];
    }
}

-(NSArray *)createFMInstrumentsWith:(NSString *)cartridge numberOfChannels:(NSUInteger)numberOfChannels {
    NSMutableArray *fmInstruments = [NSMutableArray arrayWithCapacity:MIDI_PLAYER_MAXIMIUM_TRACKS];
    NSData *sysex = [self.sysexTable objectForKey:cartridge];
    for (int i = 0; i < numberOfChannels; i++) {
        FMInstrument *fmInstrument = [[FMInstrument alloc] initWitHSysex:sysex];
        [fmInstrument setTrackNumber:i];
        NSLog(@"Creating FM instrument for track: %i", i);
        [fmInstruments addObject:fmInstrument];
    }
    return [fmInstruments copy];
}

@end
