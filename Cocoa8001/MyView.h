//#define USE_CA

#if defined(USE_GL3) && !defined(USE_CA)
#define USE_CA
#endif

#if defined(USE_METAL)
typedef MTKView MY_SUPER;
#elif defined(USE_CA)
typedef NSView MY_SUPER;
#else
typedef NSOpenGLView MY_SUPER;
#endif

void LoadFont();

class MyGL;
@class MyDocument;

@interface MyView : MY_SUPER {
	int curAtr, graph, color, cursX, cursY;
	BOOL _rotation;
	MyGL *gl;
	GLfloat *vtx;
#ifdef USE_METAL
	id<MTLComputePipelineState> _computePipelineState;
	id<MTLRenderPipelineState> _renderPipelineState;
	id<MTLCommandQueue> _commandQueue;
	id<MTLTexture> _tex;
	id<MTLBuffer> _chr, _vtx, _prm, _rot;
#endif
#ifndef USE_GL3
	GLfloat *tex;
	GLuint *vtxcolor;
#endif
}

- (MyDocument *)document;
- (void)close;
- (void)setCursX:(int)x Y:(int)y;
- (void)setRotation:(BOOL)f;

@property (nonatomic, assign) BOOL width80, height25, colorMode, active, focus, needsRefresh;

@end
