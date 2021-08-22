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

@class MyDocument;

@interface MyView : MY_SUPER

- (MyDocument *)document;
- (void)close;
- (void)setCursX:(int)x Y:(int)y;
- (void)setRotation:(BOOL)f;

@property (nonatomic) BOOL width80, height25, colorMode, active, focus, needsRefresh;

@end

void LoadFont();
