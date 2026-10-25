// LiquidChibiMenu.m
// iOS Objective-C source template for a draggable Liquid Glass utility menu.
// This is SOURCE CODE, not a compiled .dylib. Build/signing and injection are separate steps.
// Note: background YouTube audio is not guaranteed in an injected overlay. iOS background
// playback generally requires the host app to support the audio background mode.

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/utsname.h>

@interface LCMMenu : NSObject <WKNavigationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *rainbowBorder;
@property (nonatomic, strong) UIButton *toggle;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UIStackView *tabBar;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) CADisplayLink *fpsLink;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) CFTimeInterval lastFPSUpdate;
@property (nonatomic, strong) UILabel *fpsLabel;
@end

@implementation LCMMenu

static LCMMenu *gMenu;

static UIColor *LCMColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.window) return;

        // Separate overlay window. Some host apps / iOS versions may restrict this.
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.window.windowLevel = UIWindowLevelAlert + 2;
        self.window.backgroundColor = UIColor.clearColor;
        self.window.rootViewController = [UIViewController new];
        self.window.rootViewController.view.backgroundColor = UIColor.clearColor;
        self.window.hidden = NO;

        [self buildToggle];
        [self buildPanel];
        [self showTab:0];
    });
}

- (void)buildToggle {
    self.toggle = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggle.frame = CGRectMake(18, UIScreen.mainScreen.bounds.size.height * 0.42, 54, 54);
    self.toggle.backgroundColor = LCMColor(35, 28, 52, 0.94);
    self.toggle.layer.cornerRadius = 0; // square, no rounded corners
    self.toggle.layer.borderWidth = 2;
    self.toggle.layer.borderColor = LCMColor(255, 120, 235, 1).CGColor;
    [self.toggle setTitle:@"✦" forState:UIControlStateNormal];
    self.toggle.titleLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightBlack];
    [self.toggle addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.window addSubview:self.toggle];
    [self addDragToView:self.toggle];
}

- (void)buildPanel {
    CGFloat w = MIN(350, UIScreen.mainScreen.bounds.size.width - 28);
    CGFloat h = MIN(470, UIScreen.mainScreen.bounds.size.height - 100);
    self.panel = [[UIView alloc] initWithFrame:CGRectMake((UIScreen.mainScreen.bounds.size.width-w)/2,
                                                           (UIScreen.mainScreen.bounds.size.height-h)/2,
                                                           w, h)];
    self.panel.hidden = YES;
    self.panel.backgroundColor = LCMColor(28, 24, 44, 0.72);
    self.panel.layer.cornerRadius = 26;
    self.panel.layer.borderWidth = 2.0;
    self.panel.layer.borderColor = LCMColor(255, 150, 235, 0.95).CGColor;
    self.panel.layer.shadowColor = UIColor.blackColor.CGColor;
    self.panel.layer.shadowOpacity = 0.28;
    self.panel.layer.shadowRadius = 24;
    self.panel.layer.shadowOffset = CGSizeMake(0, 10);

    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:blur];
        glass.frame = self.panel.bounds;
        glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        glass.userInteractionEnabled = NO;
        glass.layer.cornerRadius = 26;
        glass.clipsToBounds = YES;
        [self.panel addSubview:glass];
    }

    // Rainbow gradient border overlay.
    self.rainbowBorder = [[UIView alloc] initWithFrame:self.panel.bounds];
    self.rainbowBorder.userInteractionEnabled = NO;
    self.rainbowBorder.backgroundColor = UIColor.clearColor;
    self.rainbowBorder.layer.cornerRadius = 26;
    self.rainbowBorder.layer.borderWidth = 2.5;
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.panel.bounds;
    gradient.colors = @[
        (id)[UIColor systemPinkColor].CGColor,
        (id)[UIColor systemPurpleColor].CGColor,
        (id)[UIColor systemBlueColor].CGColor,
        (id)[UIColor systemTealColor].CGColor,
        (id)[UIColor systemYellowColor].CGColor,
        (id)[UIColor systemPinkColor].CGColor
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.cornerRadius = 26;
    [self.rainbowBorder.layer insertSublayer:gradient atIndex:0];
    self.rainbowBorder.layer.mask = [self roundedBorderMaskForRect:self.panel.bounds radius:26 width:2.5];
    self.rainbowBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.rainbowBorder];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, w-72, 34)];
    title.text = @"🌈 Liquid Chibi";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.panel addSubview:title];

    UIButton *close = [self cuteButton:@"✕" frame:CGRectMake(w-48, 8, 36, 34)];
    [close addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:close];

    self.tabBar = [[UIStackView alloc] initWithFrame:CGRectMake(12, 49, w-24, 42)];
    self.tabBar.axis = UILayoutConstraintAxisHorizontal;
    self.tabBar.distribution = UIStackViewDistributionFillEqually;
    self.tabBar.spacing = 7;
    NSArray *names = @[@"🌐 Web", @"▶ YouTube", @"📱 Máy"];
    for (NSInteger i=0; i<names.count; i++) {
        UIButton *b = [self cuteButton:names[i] frame:CGRectZero];
        b.tag = i;
        [b addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBar addArrangedSubview:b];
    }
    [self.panel addSubview:self.tabBar];

    self.content = [[UIView alloc] initWithFrame:CGRectMake(12, 100, w-24, h-112)];
    self.content.backgroundColor = LCMColor(10, 10, 20, 0.26);
    self.content.layer.cornerRadius = 18;
    self.content.clipsToBounds = YES;
    [self.panel addSubview:self.content];

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.allowsInlineMediaPlayback = YES;
    if (@available(iOS 10.0, *)) config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    self.webView = [[WKWebView alloc] initWithFrame:self.content.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    self.webView.opaque = NO;
    self.webView.backgroundColor = UIColor.clearColor;
    self.webView.scrollView.backgroundColor = UIColor.clearColor;
    [self.content addSubview:self.webView];

    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.content.bounds, 14, 14)];
    self.infoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.textColor = UIColor.whiteColor;
    self.infoLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.infoLabel.hidden = YES;
    [self.content addSubview:self.infoLabel];

    // Requested image link, shown in the device-info tab as a small chibi-style decoration.
    NSURL *imageURL = [NSURL URLWithString:@"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQDMIJx2zbjMs8c9GxruQgPDdsRSkCIH0Zxtt1gHoL-Ng&s=10"];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.content.bounds.size.width-74, 8, 58, 58)];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.layer.cornerRadius = 12;
    imageView.layer.borderWidth = 1.5;
    imageView.layer.borderColor = UIColor.systemPinkColor.CGColor;
    [self.content addSubview:imageView];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:imageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            UIImage *img = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{ imageView.image = img; });
        }
    }];
    [task resume];

    [self.window addSubview:self.panel];
    [self addDragToView:title];
    [self addDragToView:self.panel];
    [self startFPS];
}

- (CAShapeLayer *)roundedBorderMaskForRect:(CGRect)rect radius:(CGFloat)radius width:(CGFloat)width {
    CAShapeLayer *mask = [CAShapeLayer layer];
    UIBezierPath *outer = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    UIBezierPath *inner = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, width, width) cornerRadius:MAX(0, radius-width)];
    [outer appendPath:[inner bezierPathByReversingPath]];
    mask.path = outer.CGPath;
    mask.fillRule = kCAFillRuleEvenOdd;
    return mask;
}

- (UIButton *)cuteButton:(NSString *)title frame:(CGRect)frame {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    b.backgroundColor = LCMColor(125, 76, 190, 0.72);
    b.layer.cornerRadius = 13;
    b.layer.borderWidth = 1;
    b.layer.borderColor = LCMColor(255, 190, 250, 0.8).CGColor;
    return b;
}

- (void)playClick {
    // Short system click sound; device mute/accessibility settings may affect audible feedback.
    AudioServicesPlaySystemSound(1104);
}

- (void)togglePanel {
    [self playClick];
    self.panel.hidden = !self.panel.hidden;
    self.toggle.backgroundColor = self.panel.hidden ? LCMColor(35, 28, 52, 0.94) : LCMColor(40, 145, 90, 0.96);
}

- (void)tabPressed:(UIButton *)sender {
    [self playClick];
    [self showTab:sender.tag];
}

- (void)showTab:(NSInteger)index {
    self.webView.hidden = (index == 2);
    self.infoLabel.hidden = (index != 2);
    if (index == 0) {
        if (!self.webView.URL) {
            [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]]];
        }
        // Add a compact home/back toolbar over the web page.
        [self addBrowserToolbarIfNeeded];
    } else if (index == 1) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://m.youtube.com"]]];
        self.webView.hidden = NO;
        [self addBrowserToolbarIfNeeded];
    } else {
        struct utsname systemInfo;
        uname(&systemInfo);
        UIDevice *device = UIDevice.currentDevice;
        device.batteryMonitoringEnabled = YES;
        NSString *model = [NSString stringWithUTF8String:systemInfo.machine];
        NSString *version = device.systemVersion ?: @"Unknown";
        NSString *battery = device.batteryLevel < 0 ? @"Không khả dụng" : [NSString stringWithFormat:@"%.0f%%", device.batteryLevel * 100];
        NSString *fps = self.fpsLabel.text ?: @"Đang đo...";
        self.infoLabel.text = [NSString stringWithFormat:@"📱 THÔNG TIN THIẾT BỊ\n\nDòng máy: %@\niOS: %@\nPin: %@\nFPS giao diện: %@\n\nLưu ý: FPS ở đây là FPS của giao diện menu, không phải FPS nội bộ của ứng dụng/game.", model, version, battery, fps];
    }
}

- (void)addBrowserToolbarIfNeeded {
    NSInteger tag = 8123;
    UIView *old = [self.content viewWithTag:tag];
    [old removeFromSuperview];
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(6, 6, self.content.bounds.size.width-12, 38)];
    bar.tag = tag;
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    bar.backgroundColor = LCMColor(25, 20, 40, 0.88);
    bar.layer.cornerRadius = 12;
    UIButton *home = [self cuteButton:@"⌂ Trang chính" frame:CGRectMake(4, 3, 104, 32)];
    [home addTarget:self action:@selector(homePressed) forControlEvents:UIControlEventTouchUpInside];
    UIButton *back = [self cuteButton:@"‹ Quay lại" frame:CGRectMake(114, 3, 92, 32)];
    [back addTarget:self action:@selector(backPressed) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:home];
    [bar addSubview:back];
    [self.content addSubview:bar];
    [self.content bringSubviewToFront:bar];
}

- (void)homePressed {
    [self playClick];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]]];
}

- (void)backPressed {
    [self playClick];
    if (self.webView.canGoBack) [self.webView goBack];
    else [self homePressed];
}

- (void)addDragToView:(UIView *)view {
    view.userInteractionEnabled = YES;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragged:)];
    [view addGestureRecognizer:pan];
}

- (void)dragged:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    CGPoint delta = [gesture translationInView:self.window];
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        // If dragging the title or panel itself, move the panel; the square toggle moves independently.
        UIView *target = (view == self.toggle) ? self.toggle : self.panel;
        CGPoint center = target.center;
        center.x += delta.x;
        center.y += delta.y;
        CGFloat halfW = target.bounds.size.width/2, halfH = target.bounds.size.height/2;
        center.x = MAX(halfW, MIN(self.window.bounds.size.width-halfW, center.x));
        center.y = MAX(halfH, MIN(self.window.bounds.size.height-halfH, center.y));
        target.center = center;
        [gesture setTranslation:CGPointZero inView:self.window];
    }
}

- (void)startFPS {
    self.fpsLabel = [UILabel new];
    self.fpsLabel.text = @"--";
    self.frameCount = 0;
    self.lastFPSUpdate = CACurrentMediaTime();
    self.fpsLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(frameTick:)];
    [self.fpsLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)frameTick:(CADisplayLink *)link {
    self.frameCount++;
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastFPSUpdate >= 1.0) {
        double fps = self.frameCount / (now - self.lastFPSUpdate);
        self.fpsLabel.text = [NSString stringWithFormat:@"%.0f", fps];
        self.frameCount = 0;
        self.lastFPSUpdate = now;
    }
}

@end

// Load automatically when this dylib is loaded into a process.
// Depending on the host app and iOS security/signing configuration, this may not be allowed.
__attribute__((constructor))
static void LCMInitialize(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMenu = [LCMMenu new];
        [gMenu start];
    });
}
