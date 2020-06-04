#import "PC8001.h"

#define BLINK_INTERVAL		45

struct BeepHist {
	BeepHist(int _beep, int _clock) : beep(_beep), clock(_clock) {}
	int beep, clock;
};

struct Sym {
	Sym(int _adr, const char *_s = "") : adr(_adr), n(0), s(_s) {}
	int adr, n;
	std::string s;
};

@class MyViewGL;
@class AppDelegate;

@interface MyDocument : NSDocument {
	uint8_t mem[0x10000];
	uint8_t lastVRAM[120 * 25];
	PC8001 pc8001;
	NSData *loadData, *saveData;
	int mstart, mlen, clockofs, beepcnt, beepmask, sgCount;
	volatile int closing;
	volatile BOOL saving, ready;
	std::deque<BeepHist> beepHist;
	std::deque<BeepHist> *beepHistP, *beepHistC;
	BOOL hexmode;
	CVDisplayLinkRef displayLink;
	std::vector<Sym> sym;
}

@property (nonatomic, assign) IBOutlet MyViewGL *view;
@property (nonatomic, assign) int blink, rowCount;
@property (nonatomic, assign) BOOL blinkMask;
@property (nonatomic, assign) AppDelegate *appDelegate;

- (void)key:(int)code isUp:(BOOL)f;
- (void)setBeep:(BOOL)beep clock:(int)clock;
- (BOOL)run:(int)sampleN buf:(float *)buf;
- (uint8_t *)vram;
- (void)position:(NSPoint)point;
- (void)becomeActive;
- (void)vsync;

@end
