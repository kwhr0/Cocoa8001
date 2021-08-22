#import "AppDelegate.h"
#import "Audio.h"
#import "MyDocument.h"
#import "MyView.h"
#import "PC8001.h"
#import "gamepad.h"
#include <arpa/inet.h>

#define ADDR	"127.0.0.1"
#define PORT	10023

static void audioCallback(float *buf, int n) {
	BOOL f = FALSE;
	@autoreleasepool {
		NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
		for (int i = 0; i < docs.count; i++) {
			id doc = [docs objectAtIndex:i];
			if ([doc isKindOfClass:[MyDocument class]]) f |= [(MyDocument *)doc run:n buf:buf];
		}
	}
	if (!f) for (int i = 0; i < n << 1; i++) buf[i] = 0.f;
}

static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now, const CVTimeStamp *outputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *context) {
	NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
	for (int i = 0; i < docs.count; i++) {
		id doc = [docs objectAtIndex:i];
		if ([doc isKindOfClass:[MyDocument class]]) [(MyDocument *)doc vsync];
	}
	return kCVReturnSuccess;
}

@interface AppDelegate () {
	CVDisplayLinkRef displayLink;
	void *gamepad_ctx;
}
@end

@implementation AppDelegate

- (void)normalizePref {
	if (_cpuClock <= 0 || _cpuClock > 1000) _cpuClock = 4;
	if (_cpuClockBoost <= 0 || _cpuClockBoost > 1000) _cpuClockBoost = 4;
	if (_cpuClockBoost < _cpuClock) _cpuClockBoost = _cpuClock;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	_cpuClock = [def doubleForKey:@"CPU_CLOCK"];
	_cpuClockBoost = [def doubleForKey:@"CPU_CLOCK_BOOST"];
	_beepMusic = [def boolForKey:@"BEEP_MUSIC"];
	[self normalizePref];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	LoadFont();
	AudioSetup(&audioCallback);
	AudioStart();
	//
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	CVDisplayLinkSetOutputCallback(displayLink, MyDisplayLinkCallback, nil);
	CVDisplayLinkStart(displayLink);
	//
	gamepad_ctx = gamepad_init(1, 0, 0);
	gamepad_set_callback(gamepad_ctx, Key::gamepadCallback);
	//
	_sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (_sock >= 0) {
		struct sockaddr_in addr = {
			.sin_family = AF_INET,
			.sin_addr = inet_addr(ADDR),
			.sin_port = PORT,
		};
		if (connect(_sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) _sock = -1;
	}
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	[def setObject:[NSNumber numberWithDouble:_cpuClock] forKey:@"CPU_CLOCK"];
	[def setObject:[NSNumber numberWithDouble:_cpuClockBoost] forKey:@"CPU_CLOCK_BOOST"];
	[def setObject:[NSNumber numberWithBool:_beepMusic] forKey:@"BEEP_MUSIC"];
	[def synchronize];
	//
	CVDisplayLinkStop(displayLink);
	CVDisplayLinkRelease(displayLink);
	//
	gamepad_term(gamepad_ctx);
	//
	if (_sock >= 0) close(_sock);
}

- (void)applicationWillBecomeActive:(NSNotification *)notification {
	NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
	if (docs.count == 1 && [[docs objectAtIndex:0] isKindOfClass:[MyDocument class]]) {
		[(MyDocument *)[docs objectAtIndex:0] becomeActive];
	}
}

- (IBAction)showPreference:(id)sender {
	if (_cpuClock < 1000.) [prefCpuClock setDoubleValue:_cpuClock];
	else [prefCpuClock setStringValue:[NSString stringWithFormat:@"%.0f", _cpuClock]];
	if (_cpuClockBoost < 1000.) [prefCpuClockBoost setDoubleValue:_cpuClockBoost];
	else [prefCpuClockBoost setStringValue:[NSString stringWithFormat:@"%.0f", _cpuClockBoost]];
	[prefBeepMusic setIntValue:_beepMusic];
	[prefPanel makeKeyAndOrderFront:nil];
}

- (IBAction)prefSet:(id)sender {
	_cpuClock = [prefCpuClock doubleValue];
	_cpuClockBoost = [prefCpuClockBoost doubleValue];
	_beepMusic = [prefBeepMusic intValue];
	[prefPanel close];
	[self normalizePref];
}

- (IBAction)prefCancel:(id)sender {
	[prefPanel close];
}

- (IBAction)tile:(id)sender {
	NSRect frame = [[NSScreen mainScreen] frame];
	int xn = frame.size.width / 640;
	NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
	int yn = ((int)[docs count] + xn - 1) / xn;
	int h = frame.size.height / yn;
	if (h > 422) h = 422;
	for (int i = 0; i < [docs count]; i++)
		[((MyDocument *)[docs objectAtIndex:i]) position:NSMakePoint(640 * (i % xn), frame.size.height - 445 - h * (i / xn))];
}

@end
