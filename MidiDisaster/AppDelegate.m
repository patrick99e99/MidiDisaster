#import "AppDelegate.h"
#import "MidiPlayer.h"
#import "FileHelper.h"
#import <OpenAL/OpenAL.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) MidiPlayer *midiPlayer;

@end

@implementation AppDelegate

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    ALCdevice *openALDevice;
    ALCcontext *openALContext;
    openALDevice = alcOpenDevice(NULL);
    openALContext = alcCreateContext(openALDevice, NULL);
    alcMakeContextCurrent(openALContext);
    
    self.midiPlayer = [[MidiPlayer alloc] init];
    NSDictionary *midiTable = [FileHelper dictionaryForFilesWithExtension:@"mid"];
    [self.midiPlayer playMidi:[midiTable objectForKey:@"theme"] cartridge:@"nb-theme"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {}

@end
