#define BLINK_INTERVAL		45

@class MyView;
@class AppDelegate;

@interface MyDocument : NSDocument

@property (nonatomic, weak) IBOutlet MyView *view;
@property (nonatomic) int blink, rowCount;
@property (nonatomic) BOOL blinkMask;
@property (nonatomic, weak) AppDelegate *appDelegate;

- (void)key:(int)code isUp:(BOOL)f;
- (void)setBeep:(BOOL)beep clock:(int)clock;
- (BOOL)run:(int)sampleN buf:(float *)buf;
- (uint8_t *)vram;
- (void)position:(NSPoint)point;
- (void)becomeActive;
- (void)vsync;

@end
