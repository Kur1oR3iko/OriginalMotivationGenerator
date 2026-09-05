#import <UIKit/UIKit.h>
#import "OMGGenerator.h"

@interface OMGViewController : UIViewController
@property (nonatomic, strong) UILabel *phraseLabel;
@end

@implementation OMGViewController
- (void)loadView {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button addTarget:self action:@selector(generate) forControlEvents:UIControlEventTouchUpInside];
    self.view = button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.phraseLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.phraseLabel.backgroundColor = [UIColor clearColor];
    self.phraseLabel.textColor = [UIColor blackColor];
    self.phraseLabel.textAlignment = NSTextAlignmentCenter;
    self.phraseLabel.numberOfLines = 1;
    self.phraseLabel.adjustsFontSizeToFitWidth = YES;
    self.phraseLabel.minimumScaleFactor = 0.1;
    self.phraseLabel.isAccessibilityElement = NO;
    [self.view addSubview:self.phraseLabel];
    self.view.isAccessibilityElement = YES;
    self.view.accessibilityLabel = @"生成原始动机";
    self.view.accessibilityTraits = UIAccessibilityTraitButton;
    self.phraseLabel.text = [OMGGenerator lastPhrase] ?: [OMGGenerator nextPhrase] ?: @"全部组合已生成完毕";
    self.view.accessibilityValue = self.phraseLabel.text;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    // Conservative margins also protect text from landscape display cutouts,
    // without linking APIs absent from the legacy SDK.
    CGFloat padding = MAX(44.0, CGRectGetWidth(bounds) * 0.04);
    self.phraseLabel.frame = CGRectInset(bounds, padding, 0);
    self.phraseLabel.font = [UIFont boldSystemFontOfSize:MIN(MAX(CGRectGetWidth(bounds) * 0.105, 80), 152)];
}
- (void)generate {
    self.phraseLabel.text = [OMGGenerator nextPhrase] ?: @"全部组合已生成完毕";
    self.view.accessibilityValue = self.phraseLabel.text;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.phraseLabel.text);
}
- (BOOL)accessibilityPerformMagicTap {
    [self generate];
    return YES;
}
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation { return UIInterfaceOrientationLandscapeLeft; }
- (BOOL)prefersStatusBarHidden { return YES; }
@end

@interface OMGAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation OMGAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [[OMGViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)applicationWillTerminate:(UIApplication *)application {
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([OMGAppDelegate class]));
    }
}
