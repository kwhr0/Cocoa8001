#import "PC8001.h"
#import "MyDocument.h"
#import "MyViewGL.h"
#import "AppDelegate.h"
#import "gamepad.h"

int32_t PC8001::input(u_short adr) {
	int32_t r = 0;
	switch (adr & 0xf0) {
		case 0:
			r = key.Get(adr);
			if (adr < 9) boostTimer = 0;
			break;
		case 0x20:
			r = adr & 1 ? 0xe1 : 0;
			break;
		case 0x40:
			r = (++vrtc & 0x20) | rtc.Get() << 4 | 0xa;
			break;
		case 0x80: // custom
			r = (key.Get(1) & 0x80) | (key.Get(0) >> 1 & 0x20) | (key.Get(0) >> 1 & 8) |
				(key.Get(0) << 4 & 0x40) | (key.Get(1) << 4 & 0x10) | (key.Get(9) >> 6 & 1) | 6;
			boostTimer = 0;
			break;
	}
	return r;
}

void PC8001::output(u_short adr, u_char data) {
	int lastbeep;
	switch (adr & 0xf0) {
		case 0x10:
			pch = data;
			break;
		case 0x30:
			doc.view.width80 = data & 1;
			break;
		case 0x40:
			prn.Strobe(~data & 1, pch);
			if (data & 2) rtc.Strobe(pch);
			else if (data & 4) rtc.Shift(pch);
			lastbeep = beep;
			beep = (data & 0x20) != 0;
			if (beep != lastbeep) {
				[doc setBeep:beep clock:clock];
			}
			break;
		case 0x50:
			if (adr & 1) crtc.Command(doc.view, data);
			else crtc.Parameter(doc.view, data);
			break;
		case 0x60:
			if ((adr & 0xf) == 8) dma.Command(data);
			else dma.Parameter(data);
			break;
		case 0x90:
			sg.Set(data);
			break;
	}
}

bool PC8001::Extender(u_short pc) {
	bool f = sel && pc == 0x20;
	if (f) {
		[doc performSelector:sel];
		sel = nil;
	}
	return f;
}

int Key::gamepadDir, Key::gamepadBtn;

void Key::gamepadCallback(int type, int page, int usage, int value) {
	static bool left, right, up, down;
	if (type == 1 && page == 1) {
		if (usage == 57) gamepadDir = value;
		else if (usage == 48 || usage == 49) {
			if (usage == 48) {
				left = usage == 48 && value < 0x50;
				right = usage == 48 && value > 0xb0;
			}
			if (usage == 49) {
				up = usage == 49 && value < 0x50;
				down = usage == 49 && value > 0xb0;
			}
			gamepadDir = up ? left ? 7 : right ? 1 : 0 : down ? left ? 5 : right ? 3 : 4 : left ? 6 : right ? 2 : -1;
		}
	}
	if (type == 2 && page == 9) {
		if (value) gamepadBtn |= 1 << (usage - 1);
		else gamepadBtn &= ~(1 << (usage - 1));
	}
}

void Key::Changed(int v, int f) {
	int port = v >> 3 & 0xf;
	int mask = 1 << (v & 7);
	if (f) d[port] |= mask;
	else d[port] &= ~mask;
}
int Key::Get(int x) {
	x &= 0xf;
	int a = gamepadDir, b = gamepadBtn;
	switch (x) {
		case 0:
			return d[x] & ~((a >= 1 && a <= 3) << 6) & ~((a >= 3 && a <= 5) << 2) & ~((a >= 5 && a <= 7) << 4);
		case 1:
			return d[x] & ~(a == 0 || a == 1 || a == 7);
		case 5:
			return d[x] & ~((b & 4) != 0) & ~(((b & 2) != 0) << 2);
		default:
			return d[x];
	}
}

void Printer::Strobe(int pstb, int pch) {
	if (pstb && !pstb0 && pch != '\r') putchar(pch);
	pstb0 = pstb;
}

void RealTimeClock::Strobe(int v) {
	CFGregorianDate dt;
	int i;
	switch (v & 0xf) {
		case 1:
			pos = 0;
			for (i = 0; i < 5; i++) timetmp[i] = 0;
			dt = CFAbsoluteTimeGetGregorianDate(CFAbsoluteTimeGetCurrent() + tofs, NULL);
			time[4] = dt.month << 4;
			time[3] = (dt.day / 10 << 4) + dt.day % 10;
			time[2] = (dt.hour / 10 << 4) + dt.hour % 10;
			time[1] = (dt.minute / 10 << 4) + dt.minute % 10;
			time[0] = ((int)dt.second / 10 << 4) + (int)dt.second % 10;
			data = time[0] & 1;
			break;
		case 2:
			for (i = 0; i < 5; i++) time[i] = timetmp[i];
			dt.year = 1979;
			dt.month = timetmp[4] >> 4;
			dt.day = (timetmp[3] >> 4) * 10 + (timetmp[3] & 15);
			dt.hour = (timetmp[2] >> 4) * 10 + (timetmp[2] & 15);
			dt.minute = (timetmp[1] >> 4) * 10 + (timetmp[1] & 15);
			dt.second = (timetmp[0] >> 4) * 10 + (timetmp[0] & 15);
			tofs = CFGregorianDateGetAbsoluteTime(dt, NULL) - CFAbsoluteTimeGetCurrent();
			break;
	}
}

void RealTimeClock::Shift(int v) {
	if (pos < 40) {
		timetmp[pos >> 3] |= (v >> 3 & 1) << (pos & 7);
		pos++;
		data = time[pos >> 3] >> (pos & 7) & 1;
	}
}

void CRTController::Command(MyViewGL *view, int data) {
	switch (data) {
		case 0:
			seq = 5;
			active = false;
			break;
		case 0x80:
			x = y = -1;
			[view setCursX:x Y:y];
			break;
		case 0x81:
			seq = 7;
			break;
	}
}

void CRTController::Parameter(MyViewGL *view, int data) {
	if (seq) {
		switch (seq--) {
			case 3:
				view.height25 = (data & 0x1f) < 9;
				break;
			case 1:
				view.colorMode = (data & 0x40) != 0;
				active = true;
				break;
			case 7:
				x = data;
				break;
			case 6:
				y = data;
				[view setCursX:x Y:y];
				seq = 0;
				break;
		}
	}
}

void DMA::Command(int data) {
	seq = 2;
}

void DMA::Parameter(int data) {
	if (seq) {
		switch (seq--) {
			case 2:
				tmp = data;
				break;
			case 1:
				address = data << 8 | tmp;
				break;
		}
	}
}

SN76489A::SN76489A() : rng(1 << 16), white(0), nf(0), osc(0), tmp(0) {
	for (int i = 0; i < 4; i++) {
		freq[i] = cnt[i] = v[i] = 0;
		att[i] = 0.f;
	}
}

void SN76489A::Mute() {
	for (int i = 0; i < 4; i++) att[i] = 0.f;
}

void SN76489A::Set(int data) {
	static const float tbl[] = {
		0.250000f, 0.198582f, 0.157739f, 0.125297f, 0.099527f, 0.079057f, 0.062797f, 0.049882f,
		0.039622f, 0.031473f, 0.025000f, 0.019858f, 0.015774f, 0.012530f, 0.009953f, 0.000000f
	};
	if (data & 0x80) {
		int regnum = data >> 4 & 7;
		osc = regnum >> 1;
		switch (regnum) {
			case 0: case 2: case 4:
				tmp = data & 0xf;
				break;
			case 1: case 3: case 5: case 7:
				att[osc] = tbl[data & 0xf];
				break;
			case 6:
				nf = (data & 3) == 3;
				freq[3] = nf ? freq[2] << 1 : 0x20 << (data & 3);
				white = (data & 4) != 0;
				break;
		}
	}
	else if (osc != 3) {
		freq[osc] = (data & 0x3f) << 4 | tmp;
		if (!freq[osc]) freq[osc] = 1024;
		if (nf && osc == 2) freq[3] = freq[2] << 1;
	}
}

float SN76489A::Update() {
	float r = 0;
	for (int i = 0; i < 3; i++) {
		if (++cnt[i] >= freq[i]) {
			cnt[i] = 0;
			v[i] = !v[i];
		}
		r += v[i] ? att[i] : -att[i];
	}
	if (++cnt[3] >= freq[3]) {
		cnt[3] = 0;
		rng = rng >> 1 | ((rng >> 2 ^ (rng >> 3 & white)) & 1) << 16;
	}
	return r + (rng & 1 ? att[3] : -att[3]);
}
