#import "MyDocument.h"
#import "MyWindowController.h"
#import "AppDelegate.h"
#import "MyViewGL.h"

#define ROM_AMOUNT		0x8000
#define MEMORY_AMOUNT	0x10000
#define StartBASIC()	(mem[0xeb54] | mem[0xeb55] << 8)
#define EndBASIC()		(mem[0xefa0] | mem[0xefa1] << 8)
#define KEYIN_HOOK		0xf75
#define LOAD_HOOK		0x3cec
#define EXTENDER_CODE	0xe7
#define ex16(x)			((x) << 8 & 0xff00 | (x) >> 8 & 0xff)

#define SPEED_COEF		14

enum { CLOSING_WAIT = 1, CLOSING_READY };

static int getHex(char *&p, int n) {
	int r = 0;
	do {
		int c = *p++ - '0';
		if (c > 10) c -= 'A' - '0' - 10;
		if (c >= 0 && c < 16) r = r << 4 | c;
	} while (--n > 0);
	return r;
}

static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now, const CVTimeStamp *outputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *context) {
	[(MyDocument *)context vsync];
	return kCVReturnSuccess;
}

static bool cmp_adr(const Sym &a, const Sym &b) { return a.adr < b.adr; }
static bool cmp_n(const Sym &a, const Sym &b) { return a.n > b.n; }

@implementation MyDocument

- (id)init {
	[super init];
	if (self) {
		_appDelegate = [[NSApplication sharedApplication] delegate];
		CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
		CVDisplayLinkSetOutputCallback(displayLink, MyDisplayLinkCallback, self);
		CVDisplayLinkStart(displayLink);
	}
	return self;
}

- (void)close {
	for (closing = CLOSING_WAIT; closing == CLOSING_WAIT;)
		;
	[_view close];
	_view = nil;
	CVDisplayLinkStop(displayLink);
	CVDisplayLinkRelease(displayLink);
	displayLink = nil;
	[self dumpProfile];
	[super close];
}

- (void)makeWindowControllers {
	MyWindowController *windowController = [[MyWindowController alloc] initWithWindowNibName:@"MyDocument"];
	[self addWindowController:windowController];
	[[windowController window] makeKeyAndOrderFront:windowController];
	[windowController release];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	[_view setRotation:[self.displayName rangeOfString:@"_r."].location != NSNotFound];
}

- (void)dumpProfile {
	if (!sym.empty()) {
		std::vector<Sym>::iterator i;
		i = std::find_if(sym.begin(), sym.end(), [](Sym &s) { return s.s.substr(0, 5) == "idle "; });
		if (i != sym.end()) sym.erase(i);
		std::sort(sym.begin(), sym.end(), cmp_n);
		int t = 0;
		for (i = sym.begin(); i != sym.end() && i->n; i++) t += i->n;
		printf("------\n");
		for (i = sym.begin(); i != sym.end() && double(i->n) / t >= 1e-3; i++)
			printf("%4.1f%% %s", 100. * i->n / t, i->s.c_str());
		sym.clear();
	}
}

- (void)process:(int)clockN segment:(int)count {
	if (count < 1) count = 1;
	@synchronized (self) {
		for (int i = 0, e = 0; i < count && e >= 0; i++) {
			e = pc8001.Execute(clockN / count);
			clockofs += e + (count > 1 && _rowCount < 25 ? 1.2 : 1.0) * clockN / count;
			_rowCount = _rowCount + 1 & 0x1f;
			if (!sym.empty()) {
				std::vector<Sym>::iterator it = upper_bound(sym.begin(), sym.end(), Sym(pc8001.GetPC()), cmp_adr);
				if (it != sym.begin() && it != sym.end()) it[-1].n++;
			}
		}
	}
	pc8001.IncBoostTimer();
	_view.needsRefresh |= memcmp(lastVRAM, &mem[pc8001.GetVRAM()], sizeof(lastVRAM)) != 0;
	memcpy(lastVRAM, &mem[pc8001.GetVRAM()], sizeof(lastVRAM));
	if (_view.needsRefresh) [self performSelectorOnMainThread:@selector(refresh) withObject:nil waitUntilDone:NO];
}

- (BOOL)run:(int)sampleN buf:(float *)buf {
	if (!ready || !_view) return FALSE;
	if (closing == CLOSING_WAIT) {
		closing = CLOSING_READY;
		return FALSE;
	}
	if (_view.focus) {
		NSUInteger mod = [NSEvent modifierFlags];
		pc8001.KeyChanged(68, !(mod & NSAlternateKeyMask));
		pc8001.KeyChanged(69, !(mod & NSAlphaShiftKeyMask));
		pc8001.KeyChanged(70, !(mod & NSShiftKeyMask));
		pc8001.KeyChanged(71, !(mod & NSControlKeyMask));
	}
	if (++_blink == BLINK_INTERVAL) _view.needsRefresh = YES;
	if (_blink >= BLINK_INTERVAL << 1) {
		_view.needsRefresh = YES;
		_blink = 0;
		_blinkMask = !_blinkMask;
	}
	int clockN = SPEED_COEF * sampleN * (pc8001.CheckKeyScan() ? _appDelegate.cpuClock : _appDelegate.cpuClockBoost);
	int b = pc8001.GetBeep();
	clockofs = 0;
	_view.active = pc8001.CRTCIsActive();
	if (_view.focus) {
		beepHist.clear();
		beepHistP = &beepHist;
		const double DMA_CYCLE = 8 * (80 + 32) * 8 / 14318180.;
		int n = (pc8001.CRTCIsActive() && !_appDelegate.beepMusic && !hexmode) || !sym.empty() ? sampleN / 44100. / DMA_CYCLE : 1;
		[self process:clockN segment:n];
		sgCount += sampleN;
		int sgUpdateCount = sgCount >> 9;
		sgCount &= 0x1ff;
		for (int i = 0; i < sampleN; i++) {
			if (!beepHist.empty() && beepHist.front().clock <= clockN * i / sampleN) {
				b = beepHist.front().beep;
				beepHist.pop_front();
			}
			float v = 0.f;
			for (int j = 0; j < sgUpdateCount; j++) v = pc8001.SGUpdate();
			buf[i << 1] = buf[(i << 1) + 1] = (b & (beepmask | _appDelegate.beepMusic) ? 0.1f : 0.f) + 0.5f * v;
			if (++beepcnt >= 9) beepcnt = 0, beepmask = !beepmask;
		}
	}
	else {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			beepHistP = NULL;
			ready = FALSE; // to ignore "run" until process ended
			[self process:clockN segment:1];
			ready = TRUE;
		});
	}
	return _view.focus;
}

- (void)vsync {
	if (hexmode) pc8001.INT(0xff);
}

- (void)refresh {
#ifndef USE_CA
	[_view setNeedsDisplay:YES];
#endif
	_view.focus = [[[NSApplication sharedApplication] keyWindow] firstResponder] == _view;
}

- (void)setBeep:(BOOL)beep clock:(int)clock {
	if (beepHistP) beepHistP->push_back(BeepHist(beep, clock + clockofs));
}

- (void)loadBASIC {
	static uint8_t romadd[] = {
		0xff, 0xff, 0xc3, 0x00, 0x00, 0xcd, 0x86, 0x5b,
		0xe7, 0x21, 0x22, 0x60, 0xcd, 0xed, 0x52, 0xc3,
		0x81, 0x00, 0xcd, 0x76, 0x3d, 0x23, 0x22, 0xa0,
		0xef, 0x21, 0x29, 0x60, 0xcd, 0xed, 0x52, 0xc3,
		0x8e, 0x1f, 0x73, 0x61, 0x76, 0x65, 0x64, 0x2e,
		0x00, 0x6c, 0x6f, 0x61, 0x64, 0x65, 0x64, 0x2e,
		0x0d, 0x0a, 0x00
	};
	const char *path = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"../pc8001.rom"] fileSystemRepresentation];
	FILE *fi = fopen(path, "rb");
	if (fi != NULL) {
		fseek(fi, 0, SEEK_END);
		size_t len = (int)ftell(fi);
		rewind(fi);
		if (len > ROM_AMOUNT) len = ROM_AMOUNT;
		fread(mem, len, 1, fi);
		fclose(fi);
		int i;
		for (i = 0; i < sizeof(romadd); i++) mem[i + len] = romadd[i];
		for (i += len; i < ROM_AMOUNT; i++) mem[i] = 0xff;
		while (i < MEMORY_AMOUNT) {
			while (!(i & 0x40)) mem[i++] = 0xff;
			while (i & 0x40) mem[i++] = 0;
		}
		mem[KEYIN_HOOK] = EXTENDER_CODE;
		pc8001.SetBreak(@selector(initDone), 0);
	}
	else NSLog(@"pc8001.rom not found.");
	pc8001.SetMemoryPtr(mem);
	pc8001.SetDoc(self);
}

- (void)initDone {
	mem[KEYIN_HOOK] = 0xcd;
}

- (BOOL)loadIntelHex {
	[self dumpProfile];
	FILE *fi = fopen(self.fileURL.path.fileSystemRepresentation, "r");
	if (fi) {
		char s[256];
		while (fgets(s, sizeof(s), fi)) if (*s == ':') {
			char *p = s + 1;
			int n = getHex(p, 2), a = getHex(p, 4), t = getHex(p, 2);
			if (t) break;
			while (--n >= 0) mem[a++] = getHex(p, 2);
		}
		fclose(fi);
		NSString *path = [self.fileURL.path.stringByDeletingPathExtension stringByAppendingString:@".adr"];
		fi = fopen(path.fileSystemRepresentation, "r");
		if (!fi) return YES;
		while (fgets(s, sizeof(s), fi)) {
			int adr;
			if (sscanf(s, "%x", &adr) == 1 && strlen(s) > 5) sym.push_back(Sym(adr, s + 5));
		}
		fclose(fi);
		sym.push_back(Sym(0xffff));
		return YES;
	}
	return NO;
}

- (void)becomeActive {
	@synchronized (self) {
		if (hexmode && [self loadIntelHex]) pc8001.Reset();
	}
}

- (id)initWithType:(NSString *)typeName error:(NSError **)outError {
	[self loadBASIC];
	ready = YES;
	return [super initWithType:typeName error:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	if ([typeName isEqualToString:@"IntelHex"]) {
		BOOL r = [self loadIntelHex];
		if (!r) return NO;
		pc8001.SetMemoryPtr(mem);
		pc8001.SetDoc(self);
		hexmode = YES;
		ready = YES;
		return YES;
	}
	[self loadBASIC];
	mem[KEYIN_HOOK] = 0xcd;
	mem[LOAD_HOOK] = EXTENDER_CODE;
	loadData = [data retain];
	pc8001.SetBreak(@selector(callbackLoad), 0);
	ready = YES;
	return YES;
}

struct Header {
	u_short jmp, lenb, stm, lenm, cmt_check, pad1, pad2, pad3;
};

- (void)callbackLoad {
	uint8_t *data = (uint8_t *)[loadData bytes];
	Header head = *(Header *)[loadData bytes];
	head.jmp = ex16(head.jmp);
	head.lenb = ex16(head.lenb);
	head.stm = ex16(head.stm);
	head.lenm = ex16(head.lenm);
	if (head.cmt_check == 0xd3d3) {
		u_char *p, *dp, *start = data + sizeof(Header), *lim = data + [loadData length];
		for (p = start; true; p++) {
			int t = 0;
			for (int i = 0; i < 10; i++) t |= p[i];
			if (!t) break;
		}
		memcpy(&mem[StartBASIC()], start, p - start + 3);
		while (p < lim && *p++ != 0x3a)
			;
		if (p < lim) {
			dp = &mem[mstart = p[0] << 8 | p[1]];
			p += 3;
			mlen = 0;
			while (p < lim && *p == 0x3a) {
				p++;
				int n;
				mlen += n = *p++;
				while (n--) *dp++ = *p++;
				p++;
			}
		}
	}
	else {
		if (head.lenm) memcpy(&mem[head.stm], &data[head.lenb + sizeof(Header)], head.lenm);
		if (head.lenb) memcpy(&mem[StartBASIC()], &data[sizeof(Header)], head.lenb);
		mstart = head.stm;
		mlen = head.lenm;
	}
	mem[LOAD_HOOK] = 0xcd;
	pc8001.SetBreak(NULL, head.lenb ? 0x6012 : head.jmp);
	[loadData release];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
	if (hexmode || ![typeName isEqualToString:@"8001"]) return nil;
	saving = TRUE;
	@synchronized (self) {
		pc8001.SetBreak(@selector(callbackSave), 0x6005);
	}
	while (saving)
		;
	return [saveData autorelease];
}

- (void)callbackSave {
	u_char *p = &mem[StartBASIC()];
	long lenb = &mem[EndBASIC()] - p;
	char *buf = (char *)calloc(1, lenb + mlen + sizeof(Header));
	Header *head = (Header *)buf;
	head->lenb = ex16(lenb);
	head->stm = ex16(mstart);
	head->lenm = ex16(mlen);
	memmove(&buf[sizeof(Header)], p, lenb);
	memmove(&buf[lenb + sizeof(Header)], &mem[mstart], mlen);
	saveData = [[NSData alloc] initWithBytes:buf length:lenb + mlen + sizeof(Header)];
	free(buf);
	saving = FALSE;
}

- (void)key:(int)code isUp:(BOOL)f {
	static uint8_t kbdTransTbl[] = {
		17, 35, 20, 22, 24, 23, 42, 40, 19, 38, 0, 18, 33, 39, 21, 34,
		41, 36, 49, 50, 51, 52, 54, 53, 46, 57, 55, 47, 56, 48, 43, 31,
		37, 16, 25, 32, 15, 28, 26, 58, 27, 59, 45, 60, 62, 30, 29, 61,
		73, 78, 0, 67, 0, 79, 0, 255, 70, 255, 255, 71, 70, 255, 255, 0,
		0, 14, 0, 10, 0, 11, 0, 64, 0, 0, 0, 62, 15, 0, 47, 0,
		0, 12, 0, 1, 2, 3, 4, 5, 6, 7, 0, 8, 9, 44, 63, 0,
		77, 0, 0, 75, 0, 0, 0, 0, 0, 72, 72, 0, 0, 0, 0, 72,
		0, 0, 0, 64, 44, 67, 76, 72, 74, 63, 73, 81, 66, 80, 65, 0,
	};
	pc8001.KeyChanged(kbdTransTbl[code], f);
}

- (uint8_t *)vram { return mem + pc8001.GetVRAM(); }

- (void)position:(NSPoint)point {
	[_view.window setFrameOrigin:point];
	[_view.window orderFront:nil];
}

@end
