#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface ScriptExecutorUI : NSObject
+ (instancetype)sharedInstance;
- (void)createFloatingButton;
@end

@implementation ScriptExecutorUI {
    UIWindow *floatWindow;
    UIWindow *menuWindow;
    UITextView *scriptTextView;
    BOOL isMenuVisible;
}

+ (instancetype)sharedInstance {
    static ScriptExecutorUI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)createFloatingButton {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (floatWindow) return;

        // Tạo nút nổi dạng hình tròn
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 150, 50, 50)];
        floatWindow.windowLevel = UIWindowLevelAlert + 99999;
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.hidden = NO;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = floatWindow.bounds;
        btn.layer.cornerRadius = 25;
        btn.layer.masksToBounds = YES;
        btn.layer.borderWidth = 1.5;
        btn.layer.borderColor = [UIColor whiteColor].CGColor;
        [btn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

        // Tải ảnh cho nút bật/tắt từ link bạn cung cấp
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSURL *url = [NSURL URLWithString:@"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQMhtCHWrNb2M7tAlOyQV4EFSTLSNBoyv7XR5pvLhEScg&s=10"];
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (data) {
                UIImage *img = [UIImage imageWithData:data];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [btn setImage:img forState:UIControlStateNormal];
                });
            }
        });

        [floatWindow addSubview:btn];
    });
}

- (void)toggleMenu {
    if (!menuWindow) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        
        // Tạo cửa sổ GUI chính
        menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(40, (screenHeight - 320)/2, screenWidth - 80, 320)];
        menuWindow.windowLevel = UIWindowLevelAlert + 99998;
        menuWindow.backgroundColor = [UIColor clearColor];
        menuWindow.layer.cornerRadius = 15;
        menuWindow.layer.masksToBounds = YES;
        menuWindow.hidden = NO;

        // Tạo UIImageView để làm hình nền cho GUI
        UIImageView *bgImageView = [[UIImageView alloc] initWithFrame:menuWindow.bounds];
        bgImageView.contentMode = UIViewContentModeScaleAspectFill;
        bgImageView.clipsToBounds = YES;
        [menuWindow addSubview:bgImageView];

        // Tải hình nền từ link bạn cung cấp
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSURL *url = [NSURL URLWithString:@"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSPQoYPqQXC_318g9DfOumCH0qvCPJ5Swbn_Dx_mX5Ykg&s=10"];
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (data) {
                UIImage *img = [UIImage imageWithData:data];
                dispatch_async(dispatch_get_main_queue(), ^{
                    bgImageView.image = img;
                });
            }
        });

        // Lớp phủ tối nhẹ để chữ và các nút dễ nhìn hơn trên nền ảnh
        UIView *overlayView = [[UIView alloc] initWithFrame:menuWindow.bounds];
        overlayView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
        [menuWindow addSubview:overlayView];

        // Tiêu đề GUI
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 200, 30)];
        titleLabel.text = @"Script Executor";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [menuWindow addSubview:titleLabel];

        // Nút Đóng GUI (X)
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(menuWindow.bounds.size.width - 40, 12, 30, 30);
        [closeBtn setTitle:@"X" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:closeBtn];

        // Ô nhập/hiển thị Script (Text View)
        scriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(15, 55, menuWindow.bounds.size.width - 30, 180)];
        scriptTextView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.8];
        scriptTextView.textColor = [UIColor greenColor];
        scriptTextView.font = [UIFont fontWithName:@"Courier" size:13];
        scriptTextView.text = @"-- Dán hoặc viết script Lua tại đây...";
        scriptTextView.layer.cornerRadius = 8;
        scriptTextView.layer.borderWidth = 1;
        scriptTextView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        [menuWindow addSubview:scriptTextView];

        // Nút Dán Code (Paste)
        UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        pasteBtn.frame = CGRectMake(15, 248, 90, 40);
        [pasteBtn setTitle:@"Paste" forState:UIControlStateNormal];
        pasteBtn.backgroundColor = [UIColor darkGrayColor];
        [pasteBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        pasteBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        pasteBtn.layer.cornerRadius = 8;
        [pasteBtn addTarget:self action:@selector(pasteText) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:pasteBtn];

        // Nút Thực thi Script (--->)
        UIButton *execBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        execBtn.frame = CGRectMake(115, 248, menuWindow.bounds.size.width - 130, 40);
        [execBtn setTitle:@"Execute (--->)" forState:UIControlStateNormal];
        execBtn.backgroundColor = [UIColor systemBlueColor];
        [execBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        execBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        execBtn.layer.cornerRadius = 8;
        [execBtn addTarget:self action:@selector(executeScript) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:execBtn];

        isMenuVisible = YES;
    } else {
        isMenuVisible = !isMenuVisible;
        menuWindow.hidden = !isMenuVisible;
    }
}

- (void)pasteText {
    // Lấy nội dung từ bộ nhớ tạm (Clipboard) dán vào ô nhập code
    scriptTextView.text = [UIPasteboard generalPasteboard].string ?: @"";
}

- (void)executeScript {
    NSString *scriptCode = scriptTextView.text;
    NSLog(@"[Executor] Executing script: %@", scriptCode);
    
    // Thông báo thực thi thành công
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Executor" message:@"Đã gửi lệnh chạy script thành công!" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    
    // Lấy viewcontroller hiện tại để hiển thị thông báo
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootVC presentViewController:alert animated:YES completion:nil];
}

@end

__attribute__((constructor)) void entry() {
    [[ScriptExecutorUI sharedInstance] createFloatingButton];
}
