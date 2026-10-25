#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <mach/mach.h>

// --- Forward Declarations ---
@interface CustomGUIWindow : UIWindow
@end

@interface CuteGUIController : UIViewController <WKNavigationDelegate>
@property (strong, nonatomic) UIView *mainContainer;
@property (strong, nonatomic) CAGradientLayer *rainbowLayer;
@property (strong, nonatomic) UIView *tab1View;
@property (strong, nonatomic) UIView *tab2View;
@property (strong, nonatomic) UIView *tab3View;
@property (strong, nonatomic) WKWebView *browserWebView;
@property (strong, nonatomic) WKWebView *youtubeWebView;
@property (strong, nonatomic) UILabel *statsLabel;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (assign, nonatomic) CFTimeInterval lastTime;
@property (assign, nonatomic) int frameCount;
@property (assign, nonatomic) int currentFPS;
@end

// --- Global Variables ---
static UIButton *floatingBtn = nil;
static UIWindow *guiWindow = nil;
static CuteGUIController *guiController = nil;

// Play system click sound helper
void playClickSound() {
    AudioServicesPlaySystemSound(1104); // Standard iOS click/tick sound
}

// Get exact device model name
NSString* getExactDeviceModel() {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *code = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    if ([code isEqualToString:@"iPhone15,2"]) return @"iPhone 14 Pro";
    if ([code isEqualToString:@"iPhone15,3"]) return @"iPhone 14 Pro Max";
    if ([code isEqualToString:@"iPhone16,1"]) return @"iPhone 15 Pro";
    if ([code isEqualToString:@"iPhone16,2"]) return @"iPhone 15 Pro Max";
    if ([code isEqualToString:@"iPhone17,1"]) return @"iPhone 16 Pro";
    if ([code isEqualToString:@"iPhone17,2"]) return @"iPhone 16 Pro Max";
    return code;
}

// ==========================================
// 1. FLOATING TOGGLE BUTTON (Square, No Radius)
// ==========================================
@interface FloatingButtonManager : NSObject
+ (instancetype)sharedInstance;
- (void)createFloatingButton;
@end

@implementation FloatingButtonManager

+ (instancetype)sharedInstance {
    static FloatingButtonManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[FloatingButtonManager alloc] init];
    });
    return shared;
}

- (void)createFloatingButton {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (floatingBtn) return;
        
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;
        
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingBtn.frame = CGRectMake(30, 150, 55, 55);
        floatingBtn.layer.cornerRadius = 0; // Vuông hoàn toàn, không bo góc theo yêu cầu
        floatingBtn.clipsToBounds = YES;
        floatingBtn.layer.borderWidth = 2.0;
        floatingBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.8 alpha:1.0].CGColor;
        
        // Load image from URL asynchronously
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSURL *url = [NSURL URLWithString:@"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQDMIJx2zbjMs8c9GxruQgPDdsRSkCIH0Zxtt1gHoL-Ng&s=10"];
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (data) {
                UIImage *img = [UIImage imageWithData:data];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [floatingBtn setImage:img forState:UIControlStateNormal];
                });
            }
        });
        
        [floatingBtn addTarget:self action:@selector(toggleGUI) forControlEvents:UIControlEventTouchUpInside];
        
        // Add pan gesture for dragging
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [floatingBtn addGestureRecognizer:pan];
        
        [keyWindow addSubview:floatingBtn];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIWindow *window = gesture.view.window;
    CGPoint translation = [gesture translationInView:window];
    CGPoint center = gesture.view.center;
    gesture.view.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:window];
}

- (void)toggleGUI {
    playClickSound();
    if (!guiWindow) {
        guiWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        guiWindow.windowLevel = UIWindowLevelAlert + 1;
        guiController = [[CuteGUIController alloc] init];
        guiWindow.rootViewController = guiController;
        [guiWindow makeKeyAndVisible];
        guiWindow.hidden = NO;
    } else {
        guiWindow.hidden = !guiWindow.hidden;
    }
}

@end


// ==========================================
// 2. MAIN GUI CONTROLLER (Liquid Glass + Rainbow Border)
// ==========================================
@implementation CuteGUIController

- (void)viewDidLoad {
    [super.viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    // Main Container (Liquid Glass Effect)
    self.mainContainer = [[UIView alloc] initWithFrame:CGRectMake(40, 80, self.view.bounds.size.width - 80, 480)];
    self.mainContainer.center = self.view.center;
    
    // Liquid Glass Blur View
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    visualEffectView.frame = self.mainContainer.bounds;
    visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    visualEffectView.layer.cornerRadius = 24;
    visualEffectView.clipsToBounds = YES;
    [self.mainContainer addSubview:visualEffectView];
    
    // Translucent overlay for liquid feel
    UIView *tintView = [[UIView alloc] initWithFrame:self.mainContainer.bounds];
    tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    tintView.layer.cornerRadius = 24;
    tintView.clipsToBounds = YES;
    [self.mainContainer addSubview:tintView];
    
    self.mainContainer.layer.cornerRadius = 24;
    self.mainContainer.clipsToBounds = NO;
    
    // Rainbow Border 🌈
    self.rainbowLayer = [CAGradientLayer layer];
    self.rainbowLayer.frame = self.mainContainer.bounds;
    self.rainbowLayer.colors = @[
        (id)[UIColor redColor].CGColor,
        (id)[UIColor orangeColor].CGColor,
        (id)[UIColor yellowColor].CGColor,
        (id)[UIColor greenColor].CGColor,
        (id)[UIColor blueColor].CGColor,
        (id)[UIColor purpleColor].CGColor,
        (id)[UIColor redColor].CGColor
    ];
    self.rainbowLayer.startPoint = CGPointMake(0, 0);
    self.rainbowLayer.endPoint = CGPointMake(1, 1);
    
    CAShapeLayer *borderMask = [CAShapeLayer layer];
    borderMask.lineWidth = 3.5;
    borderMask.path = [UIBezierPath bezierPathWithRoundedRect:self.mainContainer.bounds cornerRadius:24].CGPath;
    borderMask.fillColor = [UIColor clearColor].CGColor;
    borderMask.strokeColor = [UIColor blackColor].CGColor;
    self.rainbowLayer.mask = borderMask;
    [self.mainContainer.layer addSublayer:self.rainbowLayer];
    
    [self.view addSubview:self.mainContainer];
    
    // Make GUI movable via dragging header
    UIPanGestureRecognizer *panGui = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGuiPan:)];
    [self.mainContainer addGestureRecognizer:panGui];
    
    // Setup UI Components (Tabs, Title, Content)
    [self setupHeader];
    [self setupTabs];
    [self setupTabContents];
}

- (void)handleGuiPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint center = self.mainContainer.center;
    self.mainContainer.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.view];
}

- (void)setupHeader {
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, self.mainContainer.bounds.size.width - 60, 30)];
    titleLabel.text = @"✨ CUTE CHIBI MENU ✨";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.mainContainer addSubview:titleLabel];
    
    // Close / Hide Button (Chibi Style)
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(self.mainContainer.bounds.size.width - 45, 12, 35, 35];
    [closeBtn setTitle:@"❌" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:0.6];
    closeBtn.layer.cornerRadius = 17.5;
    [closeBtn addTarget:self action:@selector(closeGUI) forControlEvents:UIControlEventTouchUpInside];
    [self.mainContainer addSubview:closeBtn];
}

- (void)closeGUI {
    playClickSound();
    guiWindow.hidden = YES;
}

- (void)setupTabs {
    NSArray *tabTitles = @[@"🌐 Tab 1", @"📺 Tab 2", @"📊 Tab 3"];
    CGFloat btnWidth = (self.mainContainer.bounds.size.width - 40) / 3;
    
    for (int i = 0; i < 3; i++) {
        UIButton *tabBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        tabBtn.frame = CGRectMake(20 + i * btnWidth, 55, btnWidth - 5, 35];
        [tabBtn setTitle:tabTitles[i] forState:UIControlStateNormal];
        tabBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [tabBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        tabBtn.backgroundColor = [UIColor colorWithRed:0.9 green:0.6 blue:0.8 alpha:0.5];
        tabBtn.layer.cornerRadius = 10;
        tabBtn.tag = i + 1;
        [tabBtn addTarget:self action:@selector(switchTab:) forControlEvents:UIControlEventTouchUpInside];
        [self.mainContainer addSubview:tabBtn];
    }
}

- (void)switchTab:(UIButton *)sender {
    playClickSound();
    self.tab1View.hidden = (sender.tag != 1);
    self.tab2View.hidden = (sender.tag != 2);
    self.tab3View.hidden = (sender.tag != 3);
}

- (void)setupTabContents {
    CGRect contentRect = CGRectMake(20, 100, self.mainContainer.bounds.size.width - 40, self.mainContainer.bounds.size.height - 120);
    
    // --- TAB 1: Chrome Browser with Home button ---
    self.tab1View = [[UIView alloc] initWithFrame:contentRect];
    self.tab1View.backgroundColor = [UIColor clearColor];
    
    // Home Button to return to main page
    UIButton *homeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    homeBtn.frame = CGRectMake(0, 0, 100, 30);
    [homeBtn setTitle:@"🏠 Trang chính" forState:UIControlStateNormal];
    homeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    homeBtn.backgroundColor = [UIColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:0.8];
    homeBtn.layer.cornerRadius = 8;
    [homeBtn addTarget:self action:@selector(goBrowserHome) forControlEvents:UIControlEventTouchUpInside];
    [self.tab1View addSubview:homeBtn];
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.browserWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 35, contentRect.size.width, contentRect.size.height - 35) configuration:config];
    self.browserWebView.layer.cornerRadius = 12;
    self.browserWebView.clipsToBounds = YES;
    [self.browserWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]]];
    [self.tab1View addSubview:self.browserWebView];
    
    [self.mainContainer addSubview:self.tab1View];
    
    // --- TAB 2: YouTube with background audio support ---
    self.tab2View = [[UIView alloc] initWithFrame:contentRect];
    self.tab2View.backgroundColor = [UIColor clearColor];
    self.tab2View.hidden = YES;
    
    // Configure audio session for background playback
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    
    WKWebViewConfiguration *ytConfig = [[WKWebViewConfiguration alloc] init];
    ytConfig.allowsInlineMediaPlayback = YES;
    self.youtubeWebView = [[WKWebView alloc] initWithFrame:contentRect configuration:ytConfig];
    self.youtubeWebView.layer.cornerRadius = 12;
    self.youtubeWebView.clipsToBounds = YES;
    [self.youtubeWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://m.youtube.com"]]];
    [self.tab2View addSubview:self.youtubeWebView];
    
    [self.mainContainer addSubview:self.tab2View];
    
    // --- TAB 3: FPS, Device Model, iOS Version, Battery ---
    self.tab3View = [[UIView alloc] initWithFrame:contentRect];
    self.tab3View.backgroundColor = [UIColor clearColor];
    self.tab3View.hidden = YES;
    
    self.statsLabel = [[UILabel alloc] initWithFrame:self.tab3View.bounds];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.textColor = [UIColor whiteColor];
    self.statsLabel.font = [UIFont fontWithName:@"Courier-Bold" size:15] ?: [UIFont boldSystemFontOfSize:15];
    [self.tab3View addSubview:self.statsLabel];
    
    [self.mainContainer addSubview:self.tab3View];
    
    // Setup FPS Display Link
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFPS:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)goBrowserHome {
    playClickSound();
    [self.browserWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]]];
}

- (void)updateFPS:(CADisplayLink *)link {
    if (self.lastTime == 0) {
        self.lastTime = link.timestamp;
        return;
    }
    self.frameCount++;
    CFTimeInterval elapsed = link.timestamp - self.lastTime;
    if (elapsed >= 1.0) {
        self.currentFPS = (int)(self.frameCount / elapsed);
        self.frameCount = 0;
        self.lastTime = link.timestamp;
        
        // Refresh Stats on Tab 3
        if (!self.tab3View.isHidden) {
            NSString *deviceModel = getExactDeviceModel();
            NSString *iosVersion = [[UIDevice currentDevice] systemVersion];
            int batteryPercent = (int)([[UIDevice currentDevice] batteryLevel] * 100);
            if (batteryPercent < 0) batteryPercent = 100;
            
            self.statsLabel.text = [NSString stringWithFormat:
                @"💖 THÔNG TIN HỆ THỐNG 💖\n\n"
                @"🎮 FPS hiện tại: %d FPS\n"
                @"📱 Dòng máy: %@\n"
                @"🍏 Phiên bản iOS: iOS %@\n"
                @"🔋 Pin: %d%%\n\n"
                @"✨ Chúc bạn chơi game vui vẻ! ✨",
                self.currentFPS, deviceModel, iosVersion, batteryPercent];
        }
    }
}

@end


// ==========================================
// 3. DYLIB INITIALIZER
// ==========================================
__attribute__((constructor)) void initializeTweak() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloatingButtonManager sharedInstance] createFloatingButton];
    });
}
