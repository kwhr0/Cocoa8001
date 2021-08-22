@interface AppDelegate : NSObject <NSApplicationDelegate> {
	IBOutlet id prefPanel;
	IBOutlet id prefCpuClock;
	IBOutlet id prefCpuClockBoost;
	IBOutlet id prefBeepMusic;
}

- (IBAction)showPreference:(id)sender;
- (IBAction)prefSet:(id)sender;
- (IBAction)prefCancel:(id)sender;

@property (nonatomic) double cpuClock, cpuClockBoost;
@property (nonatomic) BOOL beepMusic;
@property (nonatomic) int sock;

@end
