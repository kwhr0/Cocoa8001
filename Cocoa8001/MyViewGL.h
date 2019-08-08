//#define USE_CA

#if defined(USE_GL3) && !defined(USE_CA)
#define USE_CA
#endif

#ifdef USE_CA
typedef NSView MY_SUPER;
#else
typedef NSOpenGLView MY_SUPER;
#endif

void LoadFont();

class MyGL;
@class MyDocument;

@interface MyViewGL : MY_SUPER {
	int curAtr, graph, color, cursX, cursY;
	BOOL _width80, _height25, _colorMode, _active, _focus, _needsRefresh, _rotation;
	MyGL *gl;
	GLfloat *vtx;
#ifndef USE_GL3
	GLfloat *tex;
	GLuint *vtxcolor;
#endif
}

- (MyDocument *)document;
- (void)close;
- (void)setCursX:(int)x Y:(int)y;
- (void)rotation;

@property (nonatomic, assign) BOOL width80, height25, colorMode, active, focus, needsRefresh;

@end
