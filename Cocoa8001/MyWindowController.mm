#import "MyWindowController.h"
#import "MyDocument.h"

@implementation MyWindowController

- (void)windowDidLoad {
	((MyDocument *)self.document).view = _view;
	[((MyDocument *)self.document) windowControllerDidLoadNib:self];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
	return [displayName stringByReplacingOccurrencesOfString:@"_r." withString:@"."].stringByDeletingPathExtension;
}

@end
