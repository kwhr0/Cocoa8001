@interface AppDelegate : NSObject <NSApplicationDelegate> {
	IBOutlet id prefPanel;
	IBOutlet id prefCpuClock;
	IBOutlet id prefCpuClockBoost;
	IBOutlet id prefBeepMusic;
	void *gamepad_ctx;
}

- (IBAction)showPreference:(id)sender;
- (IBAction)prefSet:(id)sender;
- (IBAction)prefCancel:(id)sender;

@property (nonatomic, assign) double cpuClock, cpuClockBoost;
@property (nonatomic, assign) BOOL beepMusic;

@end
