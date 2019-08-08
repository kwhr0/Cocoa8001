#import "MyViewGL.h"
#import "MyDocument.h"
#import "SimpleGL.h"

#define STRIDE				24

static uint8 *sFont;

void LoadFont() {
	const char *path = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"../pc8001.fon"] fileSystemRepresentation];
	FILE *fi = fopen(path, "rb");
	if (fi != NULL) {
		sFont = new uint8[2048];
		fread(sFont, 2048, 1, fi);
		fclose(fi);
	}
}

#ifdef USE_GL3
struct MyGL : SimpleGL {
	static const int TEXN = 2;
	enum { WIDTH = TEXN, HEIGHT, MTX };
	MyGL() : SimpleGL(STRIDE, TEXN) {
		AddAttribute("pos_x", 0, 1);
		AddAttribute("pos_y", 4, 1);
		AddAttribute("graphic", 8, 1);
		AddAttribute("colorindex", 12, 1);
		AddAttribute("reverse", 16, 1);
		AddAttribute("secret", 20, 1);
		AddUniform("tex");
		AddUniform("vramtex");
		AddUniform("width");
		AddUniform("height");
		AddUniform("mtx");
		try {
			Compile("Shader.vsh");
			Compile("Shader.gsh");
			Compile("Shader.fsh");
			Link();
		}
		catch (const char *s) {
			fprintf(stderr, "shader setup error: %s\n", s);
			exit(1);
		}
	}
};
#endif

@implementation MyViewGL

- (void)awakeFromNib {
	[[self window] makeFirstResponder:self];
	cursY = -1;
#ifdef USE_CA
	SimpleGLLayerSetup(self, &_needsRefresh);
#endif
}

- (void)close {
	delete[] vtx;
#ifdef USE_GL3
	delete gl;
#else
	delete[] tex;
	delete[] vtxcolor;
#endif
}

- (MyDocument *)document {
	return [[NSDocumentController sharedDocumentController] documentForWindow:[self window]];
}

- (void)setCursX:(int)x Y:(int)y {
	_needsRefresh |= cursX != x || cursY != y;
	cursX = x;
	cursY = y;
}

- (void)keyDown:(NSEvent *)event {
	[[self document] key:[event keyCode] isUp:FALSE];
}

- (void)keyUp:(NSEvent *)event {
	[[self document] key:[event keyCode] isUp:TRUE];
}

- (void)prepare {
	const int TEX_X = 8 * 256;
	const int TEX_Y = 10 * 2;
	uint32 *buf = new uint32[TEX_X * TEX_Y];
	for (int c = 0; c < 256; c++) {
		uint8 *sp = &sFont[c << 3];
		uint32 *dp1 = &buf[8 * c];
		uint32 *dp2 = dp1 + TEX_X * 10;
		for (int y = 0; y < 10; y++)
			for (int x = 0; x < 8; x++) {
				int cf = y < 8 ? (sFont ? sp[y] : 0) & 0x80 >> x : 0;
				int gf = y < 8 ? c & 1 << ((x & 4) + (y >> 1)) : 0;
				dp1[TEX_X * y + x] = cf ? 0xffffffff : 0xff000000;
				dp2[TEX_X * y + x] = gf ? 0xffffffff : 0xff000000;
			}
	}
#ifdef USE_GL3
	gl = new MyGL;
	gl->BindTexture();
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, TEX_X, TEX_Y, 0, GL_RGBA, GL_UNSIGNED_BYTE, buf);
	vtx = new GLfloat[STRIDE / sizeof(GLfloat) * 80 * 25];
#else
	glEnable(GL_TEXTURE_2D);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, TEX_X, TEX_Y, 0, GL_RGBA, GL_UNSIGNED_BYTE, buf);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	vtx = new GLfloat[12 * 80 * 25];
	tex = new GLfloat[12 * 80 * 25];
	vtxcolor = new GLuint[6 * 80 * 25];
#endif
	delete[] buf;
}

- (void)drawSub:(uint8 *)vram revmask:(BOOL)revmask secretmask:(BOOL)secretmask {
	if (!_colorMode) color = 7;
	int sx = _width80 ? 1 : 2, ly = _height25 ? 25 : 20;
	bool b = self.document.blink < BLINK_INTERVAL;
	GLfloat *p = vtx;
#ifdef USE_GL3
	int lx = _width80 ? 80 : 40;
#else
	GLfloat *tp = tex;
	GLuint *cp = vtxcolor;
	GLfloat xd = _width80 ? .025f : .05f, yd = _height25 ? .08f : .1f, tyd = (_height25 ? .8f : 1.f) / 2.f;
#endif
	for (int y = 0; y < ly; y++) {
		uint8 *atr = &vram[80];
		int atrIndex = 0;
		for (int x = 0; x < 80; x += sx) {
			if (atrIndex < 40 && atr[atrIndex] == x) {
				int d = atr[atrIndex + 1];
				atrIndex += 2;
				if (!_colorMode) {
					curAtr = d & 7;
					graph = (d & 0x80) >> 7;
				}
				else if (d & 8) {
					color = d >> 5;
					graph = (d & 0x10) >> 4;
				}
				else curAtr = d & 7;
			}
			BOOL rev = (curAtr & 4) >> 2 ^ (b && _focus && cursX == x && cursY == y);
			BOOL secret = curAtr & 1 || ((curAtr & 2) >> 1 && self.document.blinkMask && !b);
#ifdef USE_GL3
			p[0] = x;
			p[1] = y;
			p[2] = graph;
			p[3] = color;
			p[4] = rev;
			p[5] = secret;
			p += STRIDE / sizeof(GLfloat);
#else
			if (rev == revmask && secret == secretmask) {
				GLfloat vx = .025f * x - 1.f, vy = 1.f - yd * y;
				p[0] = p[2] = p[10] = vx;
				p[1] = p[5] = p[9] = vy;
				p[4] = p[8] = p[6] = vx + xd;
				p[3] = p[7] = p[11] = vy - yd;
				p += 12;
				GLfloat tx = vram[x] / 256.f, ty = graph / 2.f;
				tp[0] = tp[2] = tp[10] = tx;
				tp[1] = tp[5] = tp[9] = ty;
				tp[4] = tp[8] = tp[6] = tx + 1.f / 256.f;
				tp[3] = tp[7] = tp[11] = ty + tyd;
				tp += 12;
				GLuint vc = (secret ? rev ? 0xffffff : 0
						  : (color & 1 ? 0xff0000 : 0) | (color & 2 ? 0xff : 0) | (color & 4 ? 0xff00 : 0))
						| 0xff000000;
				for (int i = 0; i < 6; i++) cp[i] = vc;
				cp += 6;
			}
#endif
		}
		vram += 120;
	}
#ifdef USE_GL3
	gl->BindBuffer();
	glBufferData(GL_ARRAY_BUFFER, STRIDE * lx * ly, vtx, GL_STATIC_DRAW);
	glDrawArrays(GL_POINTS, 0, lx * ly);
#else
	glVertexPointer(2, GL_FLOAT, 0, vtx);
	glColorPointer(4, GL_UNSIGNED_BYTE, 0, vtxcolor);
	glTexCoordPointer(2, GL_FLOAT, 0, tex);
	glDrawArrays(GL_TRIANGLES, 0, GLsizei(cp - vtxcolor));
#endif
}

- (void)drawRect:(NSRect)rect {
	static const GLfloat idtMtx[] = {
		1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1
	};
	static const GLfloat rotMtx[] = {
		0, 1, 0, 0,  -1, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1
	};
	_needsRefresh = false;
	uint8 *vram = self.document.vram;
#ifdef USE_GL3
	if (!_active || !self.document) {
		glClearColor(0.f, 0.f, 0.f, 1.f);
		glClear(GL_COLOR_BUFFER_BIT);
		return;
	}
	if (!gl) [self prepare];
	gl->SetFloat(MyGL::WIDTH, _width80 ? .025f : .05f);
	gl->SetFloat(MyGL::HEIGHT, _height25 ? .08f : .1f);
	gl->SetMtx44(MyGL::MTX, _rotation ? rotMtx : idtMtx);
	gl->BindTexture(1);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 120, 25, 0, GL_RED, GL_UNSIGNED_BYTE, vram);
	[self drawSub:vram revmask:FALSE secretmask:FALSE];
#else
	static const GLfloat black[] = { 0.f, 0.f, 0.f, 1.f }, white[] = { 1.f, 1.f, 1.f, 1.f };
	glViewport(0, 0, self.frame.size.width, self.frame.size.height);
	glMatrixMode(GL_MODELVIEW);
	glLoadMatrixf(_rotation ? rotMtx : idtMtx);
	glClearColor(0.f, 0.f, 0.f, 1.f);
	glClear(GL_COLOR_BUFFER_BIT); // always clear for secret attribute
	if (_active && self.document) {
		if (!tex) [self prepare];
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		[self drawSub:vram revmask:FALSE secretmask:FALSE];
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_BLEND);
		glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR, black);
		[self drawSub:vram revmask:TRUE secretmask:FALSE];
		glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR, white);
		[self drawSub:vram revmask:TRUE secretmask:TRUE];
	}
#ifndef USE_CA
	glFlush();
#endif
#endif
}

- (void)rotation {
	const CGFloat TITLE = 22;
	_rotation = !_rotation;
	NSRect rect = self.window.frame;
	rect.size.width = _rotation ? 400 : 640;
	rect.size.height = (_rotation ? 640 : 400) + TITLE;
	[self.window setFrame:rect display:NO];
}

@end
