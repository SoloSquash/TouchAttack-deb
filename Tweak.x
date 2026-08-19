#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#import <IOKit/hid/IOHIDEvent.h>
#import <IOKit/hid/IOHIDEventSystem.h>

// ============================================================
//  MARK: - 鼠标模拟工具类
// ============================================================

@interface MouseSimulator : NSObject
+ (void)simulateMouseMoveWithDeltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY;
+ (void)resetMousePosition;
@end

@implementation MouseSimulator

+ (void)simulateMouseMoveWithDeltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY {
    UIWindow *keyWindow = [self getKeyWindow];
    if (!keyWindow) return;
    
    CGPoint center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2,
                                 [UIScreen mainScreen].bounds.size.height / 2);
    
    [self simulateTouchAtPoint:center inWindow:keyWindow phase:UITouchPhaseBegan];
    CGPoint movedPoint = CGPointMake(center.x + deltaX * 10, center.y);
    [self simulateTouchAtPoint:movedPoint inWindow:keyWindow phase:UITouchPhaseMoved];
    [self simulateTouchAtPoint:movedPoint inWindow:keyWindow phase:UITouchPhaseEnded];
}

+ (UIWindow *)getKeyWindow {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    return keyWindow;
}

+ (void)simulateTouchAtPoint:(CGPoint)point inWindow:(UIWindow *)window phase:(UITouchPhase)phase {
    UIView *gameView = [self findGameView:window];
    if (!gameView) return;
    CGPoint gamePoint = [window convertPoint:point toView:gameView];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SimulatedMouseEventNotification"
                                                        object:nil
                                                      userInfo:@{@"x": @(gamePoint.x), @"y": @(gamePoint.y), @"phase": @(phase)}];
}

+ (UIView *)findGameView:(UIView *)view {
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

@end

// ============================================================
//  MARK: - 🥩 熟牛肉自动攻击（每秒13次 RB 键）
//  ⚠️ 只检测物品 ID，不检测名称
// ============================================================

@interface BeefAutoAttackManager : NSObject
+ (instancetype)sharedManager;
- (void)startAutoAttackIfNeeded;
- (void)stopAutoAttack;
- (void)checkHeldItem;
@end

@implementation BeefAutoAttackManager {
    BOOL _isRunning;
    BOOL _isHoldingBeef;
}

+ (instancetype)sharedManager {
    static BeefAutoAttackManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BeefAutoAttackManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRunning = NO;
        _isHoldingBeef = NO;
        [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(checkHeldItem) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)checkHeldItem {
    @try {
        id player = [self getCurrentPlayer];
        if (!player) {
            if (_isHoldingBeef) {
                _isHoldingBeef = NO;
                [self stopAutoAttack];
            }
            return;
        }
        
        id heldItem = [self getHeldItemFromPlayer:player];
        if (!heldItem) {
            if (_isHoldingBeef) {
                _isHoldingBeef = NO;
                [self stopAutoAttack];
            }
            return;
        }
        
        BOOL isBeef = [self isItemCookedBeefByID:heldItem];
        
        if (isBeef && !_isHoldingBeef) {
            _isHoldingBeef = YES;
            [self startAutoAttack];
        } else if (!isBeef && _isHoldingBeef) {
            _isHoldingBeef = NO;
            [self stopAutoAttack];
        }
    } @catch (NSException *exception) {
        if (_isHoldingBeef) {
            _isHoldingBeef = NO;
            [self stopAutoAttack];
        }
    }
}

- (id)getCurrentPlayer {
    Class gameManagerClass = NSClassFromString(@"GameManager");
    if (gameManagerClass) {
        id sharedInstance = [gameManagerClass valueForKey:@"sharedInstance"];
        if (sharedInstance) {
            id player = [sharedInstance valueForKey:@"player"];
            if (player) return player;
        }
    }
    
    Class clientClass = NSClassFromString(@"MinecraftClient");
    if (clientClass) {
        id sharedInstance = [clientClass valueForKey:@"sharedInstance"];
        if (sharedInstance) {
            id player = [sharedInstance valueForKey:@"player"];
            if (player) return player;
        }
    }
    
    id player = [[NSNotificationCenter defaultCenter] userInfo][@"localPlayer"];
    if (player) return player;
    
    return nil;
}

- (id)getHeldItemFromPlayer:(id)player {
    if (!player) return nil;
    
    id inventory = [player valueForKey:@"inventory"];
    if (!inventory) return nil;
    
    NSNumber *selectedSlot = [inventory valueForKey:@"selectedSlot"];
    if (!selectedSlot) return nil;
    
    NSArray *slots = [inventory valueForKey:@"slots"];
    if (slots && [slots count] > [selectedSlot intValue]) {
        return slots[[selectedSlot intValue]];
    }
    
    return nil;
}

- (BOOL)isItemCookedBeefByID:(id)item {
    if (!item) return NO;
    
    NSString *itemId = [item valueForKey:@"itemId"];
    if (itemId) {
        if ([itemId isEqualToString:@"minecraft:cooked_beef"] ||
            [itemId isEqualToString:@"cooked_beef"]) {
            return YES;
        }
    }
    
    NSNumber *numericId = [item valueForKey:@"id"];
    if (numericId && [numericId intValue] == 363) {
        return YES;
    }
    
    return NO;
}

- (void)startAutoAttack {
    if (_isRunning) return;
    _isRunning = YES;
    [self performRBKeyPress];
    NSLog(@"[TouchAttack] 🥩 已检测到熟牛肉（ID:363），开始自动攻击（每秒13次 RB 键）");
}

- (void)stopAutoAttack {
    _isRunning = NO;
    NSLog(@"[TouchAttack] ⏹️ 自动攻击已停止");
}

- (void)performRBKeyPress {
    if (!_isRunning) return;
    if (!_isHoldingBeef) {
        [self stopAutoAttack];
        return;
    }
    
    [self simulateGamepadRBButton];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.077 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self performRBKeyPress];
    });
}

- (void)simulateGamepadRBButton {
    GCController *controller = [GCController controllers].firstObject;
    if (!controller) {
        return;
    }
    
    GCControllerButtonInput *rbButton = controller.extendedGamepad.rightShoulder;
    if (rbButton) {
        [rbButton setValue:1.0];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.02 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [rbButton setValue:0.0];
        });
    }
}

@end

// ============================================================
//  MARK: - 手柄 LB 键跳跃 + 十字键旋转
// ============================================================

@interface TouchAttackOverlay : UIView
@property (nonatomic, assign) BOOL isRotating;
@end

@implementation TouchAttackOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.isRotating = NO;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

- (void)simulateGamepadLBButton {
    GCController *controller = [GCController controllers].firstObject;
    if (!controller) return;
    GCControllerButtonInput *lbButton = controller.extendedGamepad.leftShoulder;
    if (lbButton) {
        [lbButton setValue:1.0];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [lbButton setValue:0.0];
        });
    }
}

- (void)startRightRotation {
    if (self.isRotating) return;
    self.isRotating = YES;
    [self performRotationWithDeltaX:4.0];
}

- (void)startLeftRotation {
    if (self.isRotating) return;
    self.isRotating = YES;
    [self performRotationWithDeltaX:-4.0];
}

- (void)performRotationWithDeltaX:(CGFloat)stepDeltaX {
    int totalSteps = 70;
    CGFloat duration = 0.7;
    for (int step = 0; step < totalSteps; step++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, step * (duration / totalSteps) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [MouseSimulator simulateMouseMoveWithDeltaX:stepDeltaX deltaY:0];
            if (step == totalSteps - 1) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.02 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    self.isRotating = NO;
                });
            }
        });
    }
}

@end

// ============================================================
//  MARK: - 音效检测 + 自动跳跃（LB 键）
// ============================================================

@interface JumpHelper : NSObject
+ (void)performJump;
@end

@implementation JumpHelper

+ (void)performJump {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (keyWindow) {
        for (UIView *subview in keyWindow.subviews) {
            if ([subview isKindOfClass:[TouchAttackOverlay class]]) {
                TouchAttackOverlay *overlay = (TouchAttackOverlay *)subview;
                [overlay simulateGamepadLBButton];
                break;
            }
        }
    }
}

@end

%hook LoopbackPacketSender
- (void)sendToServer:(id)packet {
    %orig;
    NSString *packetClassName = NSStringFromClass([packet class]);
    if ([packetClassName containsString:@"LevelSoundEvent"]) {
        int soundId = [[packet valueForKey:@"sound"] intValue];
        if (soundId == 17) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.03 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [JumpHelper performJump];
            });
        }
    }
}
%end

// ============================================================
//  MARK: - 手柄监听（十字键旋转）
// ============================================================

%hook GCController
+ (void)handleControllerDidConnect:(id)controller {
    %orig;
    GCController *ctrl = (GCController *)controller;
    if (ctrl.extendedGamepad) {
        [ctrl.extendedGamepad.dpad.rightButton setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
            if (pressed) {
                UIWindow *keyWindow = nil;
                if (@available(iOS 13.0, *)) {
                    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if (scene.activationState == UISceneActivationStateForegroundActive) {
                            keyWindow = scene.windows.firstObject;
                            break;
                        }
                    }
                } else {
                    keyWindow = [UIApplication sharedApplication].keyWindow;
                }
                if (keyWindow) {
                    for (UIView *subview in keyWindow.subviews) {
                        if ([subview isKindOfClass:[TouchAttackOverlay class]]) {
                            TouchAttackOverlay *overlay = (TouchAttackOverlay *)subview;
                            [overlay startRightRotation];
                            break;
                        }
                    }
                }
            }
        }];
        
        [ctrl.extendedGamepad.dpad.leftButton setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
            if (pressed) {
                UIWindow *keyWindow = nil;
                if (@available(iOS 13.0, *)) {
                    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if (scene.activationState == UISceneActivationStateForegroundActive) {
                            keyWindow = scene.windows.firstObject;
                            break;
                        }
                    }
                } else {
                    keyWindow = [UIApplication sharedApplication].keyWindow;
                }
                if (keyWindow) {
                    for (UIView *subview in keyWindow.subviews) {
                        if ([subview isKindOfClass:[TouchAttackOverlay class]]) {
                            TouchAttackOverlay *overlay = (TouchAttackOverlay *)subview;
                            [overlay startLeftRotation];
                            break;
                        }
                    }
                }
            }
        }];
    }
}
%end

// ============================================================
//  MARK: - Hook 入口
// ============================================================

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    window = scene.windows.firstObject;
                    break;
                }
            }
        } else {
            window = [UIApplication sharedApplication].keyWindow;
        }
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
    NSLog(@"[TouchAttack] 📍 功能1: 手持熟牛肉（ID:363）→ 自动攻击（每秒13次 RB 键）");
    NSLog(@"[TouchAttack] 📍 功能2: 受伤音效检测 → 自动跳跃（LB 键）");
    NSLog(@"[TouchAttack] 📍 功能3: 手柄十字键左/右 → 旋转视角1圈（0.7秒）");
    [BeefAutoAttackManager sharedManager];
}
