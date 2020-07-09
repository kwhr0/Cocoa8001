#include "Z80.h"
#include <queue>

@class MyDocument;
@class MyView;

class Key {
public:
	Key() {
		for (int i = 0; i < 16; i++) d[i] = 255;
		gamepadDir = -1;
	}
	void Changed(int, int);
	int Get(int x);
	static void gamepadCallback(int type, int page, int usage, int value);
private:
	u_char d[16];
	static int gamepadDir, gamepadBtn;
};

class Printer {
public:
	Printer() : lpt(NULL), pstb0(0) {}
	void Strobe(int, int);
private:
	FILE *lpt;
	int pstb0;
};

class RealTimeClock {
public:
	RealTimeClock() : data(0), pos(0), tofs(0) {
		for (int i = 0; i < 5; i++) time[i] = timetmp[i] = 0;
	}
	void Strobe(int);
	void Shift(int);
	int Get() const { return data; }
private:
	int data, pos;
	int time[5], timetmp[5];
	CFAbsoluteTime tofs;
};

class CRTController {
public:
	CRTController() : seq(0), x(0), y(0), active(false) {}
	void Command(MyView *, int);
	void Parameter(MyView *, int);
	bool isActive() const { return active; }
private:
	int seq, x, y;
	bool active;
};

class DMA {
public:
	DMA() : seq(0), address(0xf300), tmp(0) {}
	void Command(int);
	void Parameter(int);
	int GetAddress() const { return address; }
private:
	int seq, address, tmp;
};

class SN76489A {
public:
	SN76489A();
	void Mute();
	void Set(int data);
	float Update();
private:
	int freq[4], cnt[4], v[4];
	float att[4];
	int rng, white, nf, osc, tmp;
};

class PC8001 : public Z80 {
public:
	PC8001() : doc(nil), sel(nil), pch(0), vrtc(0), beep(0), boostTimer(0) {}
	void SetDoc(MyDocument *_doc) { doc = _doc; }
	void SetBreak(SEL _sel, u_short _pc) { sel = _sel; pc = _pc; }
	void KeyChanged(int v, int f) { key.Changed(v, f); }
	void IncBoostTimer() { boostTimer++; }
	bool CheckKeyScan() const { return boostTimer < 7; }
	int GetBeep() const { return beep; }
	bool CRTCIsActive() const { return crtc.isActive(); }
	int GetVRAM() const { return dma.GetAddress(); }
	float SGUpdate() { return sg.Update(); }
	void Reset() { Z80::Reset(); sg.Mute(); }
	int GetPC() const { return pc; }
private:
	bool Extender(u_short);
	int32_t input(u_short);
	void output(u_short, u_char);
	MyDocument *doc;
	SEL sel;
	int pch, vrtc, beep, boostTimer;
	Key key;
	Printer prn;
	RealTimeClock rtc;
	CRTController crtc;
	SN76489A sg;
	DMA dma;
	std::queue<char> recvQ;
};
