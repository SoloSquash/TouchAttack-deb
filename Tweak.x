#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ============================================================
//  MARK: - 频率检测 + 攻击触发
// ============================================================

@interface TouchAttackOverlay : UIView
@property (nonatomic, strong) NSMutableArray *tapTimestamps;
@end

@implementation TouchAttackOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.tapTimestamps = [NSMutableArray array];
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint point = [touch locationInView:self];
        [self handleTouchAtPoint:point];
    }
}

- (void)handleTouchAtPoint:(CGPoint)point {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    BOOL isTop35 = (point.y < screenHeight * 0.35);
    BOOL isRight50 = (point.x > screenWidth * 0.50);
    
    if (isTop35 && isRight50) {
        [self recordTapAndCheckFrequency];
    }
}

- (void)recordTapAndCheckFrequency {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    [self.tapTimestamps addObject:@(now)];
    
    NSMutableArray *valid = [NSMutableArray array];
    for (NSNumber *ts in self.tapTimestamps) {
        if (now - [ts doubleValue] <= 1.0) [valid addObject:ts];
    }
    self.tapTimestamps = valid;
    
    NSInteger tapCount = self.tapTimestamps.count;
    
    if (tapCount >= 4 && tapCount <= 5) {
        [self performAttackSequence];
        [self.tapTimestamps removeAllObjects];
    } else if (tapCount > 5) {
        [self performAttackSequence];
        [self.tapTimestamps removeAllObjects];
    }
}

// 攻击间隔 83ms → 精确达到 16次/秒
- (void)performAttackSequence {
    for (int i = 0; i < 4; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, i * 0.083 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self simulateMouseLeftClick];
        });
    }
}

- (void)simulateMouseLeftClick {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    
    UIView *gameView = [self findGameView:keyWindow];
    if (gameView) {
        CGPoint center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2,
                                     [UIScreen mainScreen].bounds.size.height / 2);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SimulatedClickNotification"
                                                            object:nil
                                                          userInfo:@{@"x": @(center.x), @"y": @(center.y)}];
    }
}

- (UIView *)findGameView:(UIView *)view {
    NSArray *classNames = @[@"MTKView", @"GLKView"];
    for (NSString *className in classNames) {
        Class cls = NSClassFromString(className);
        if (cls && [view isKindOfClass:cls]) return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *result = [self findGameView:subview];
        if (result) return result;
    }
    return nil;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    BOOL isTop35 = (point.y < screenHeight * 0.35);
    BOOL isRight50 = (point.x > screenWidth * 0.50);
    if (isTop35 && isRight50) return self;
    return nil;
}

@end

// ============================================================
//  MARK: - 音效检测 + 自动跳跃（10ms）
// ============================================================

%hook LoopbackPacketSender

- (void)sendToServer:(id)packet {
    %orig;
    
    NSString *packetClassName = NSStringFromClass([packet class]);
    if ([packetClassName containsString:@"LevelSoundEvent"]) {
        int soundId = [[packet valueForKey:@"sound"] intValue];
        
        if (soundId == 17) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self performJumpNow];
            });
            NSLog(@"[TouchAttack] 🔊 检测到受伤音效！10ms后跳跃");
        }
    }
}

- (void)performJumpNow {
    [self simulateSpaceKey];
}

- (void)simulateSpaceKey {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SimulatedKeyPressNotification"
                                                        object:nil
                                                      userInfo:@{@"key": @"space"}];
}

%end

// ============================================================
//  MARK: - Hook 入口
// ============================================================

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (window) {
            static BOOL overlayAdded = NO;
            if (!overlayAdded) {
                overlayAdded = YES;
                
                TouchAttackOverlay *overlay = [[TouchAttackOverlay alloc] initWithFrame:window.bounds];
                overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                overlay.userInteractionEnabled = YES;
                overlay.multipleTouchEnabled = YES;
                [window addSubview:overlay];
                [window bringSubviewToFront:overlay];
            }
        }
    });
}

%end

%ctor {
    NSLog(@"[TouchAttack] 🚀 插件加载成功！");
    NSLog(@"[TouchAttack] 📍 功能1: 右上区域(上35%%右50%%) → 频率检测(4-5次/秒) → 攻击4次（间隔83ms，精确16次/秒）");
    NSLog(@"[TouchAttack] 📍 功能2: 游戏内音效检测 → 检测到 HURT 音效(ID=17) → 10ms后跳跃（空格键）");
}