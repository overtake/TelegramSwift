// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <objc/runtime.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#define MSViewController NSViewController
#else
#import <UIKit/UIKit.h>
#define MSViewController UIViewController
#endif

#import "MSACAnalyticsCategory.h"
#import "MSACAnalyticsInternal.h"

static NSString *const kMSACViewControllerSuffix = @"ViewController";
static NSString *MSMissedPageViewName;
static IMP viewWillAppearOriginalImp;

/**
 * Should track page.
 *
 * @param viewController The current view controller.
 *
 * @return YES if should track page, NO otherwise.
 */
static BOOL ms_shouldTrackPageView(MSViewController *viewController) {

  // For container view controllers, auto page tracking is disabled(to avoid noise).
  NSSet *viewControllerSet = [NSSet setWithArray:@[
#if TARGET_OS_OSX
    @"NSTabViewController", @"NSSplitViewController", @"NSPageController"
#else
    @"UINavigationController", @"UITabBarController", @"UISplitViewController", @"UIInputWindowController", @"UIPageViewController"
#endif
  ]];
  NSString *className = NSStringFromClass([viewController class]);
  return ![viewControllerSet containsObject:className];
}

@implementation MSViewController (PageViewLogging)

+ (void)swizzleViewWillAppear {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class class = [self class];

// Get selectors.
#if TARGET_OS_OSX
    SEL originalSelector = NSSelectorFromString(@"viewWillAppear");
#else
    SEL originalSelector = NSSelectorFromString(@"viewWillAppear:");
#endif

    SEL swizzledSelector = @selector(ms_viewWillAppear:);
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    IMP swizzledImp = class_getMethodImplementation(class, swizzledSelector);
    viewWillAppearOriginalImp = method_setImplementation(originalMethod, swizzledImp);
  });
}

#pragma mark - Method Swizzling

- (void)ms_viewWillAppear:(BOOL)animated {

  // Forward to the original implementation.
  ((void (*)(id, SEL, BOOL))viewWillAppearOriginalImp)(self, _cmd, animated);

  if ([MSACAnalytics isAutoPageTrackingEnabled]) {

    if (!ms_shouldTrackPageView(self)) {
      return;
    }

    // By default, use class name for the page name.
    NSString *pageViewName = NSStringFromClass([self class]);

    // Remove module name on swift classes.
    pageViewName = [[pageViewName componentsSeparatedByString:@"."] lastObject];

    // Remove suffix if any.
    if ([pageViewName hasSuffix:kMSACViewControllerSuffix] && [pageViewName length] > [kMSACViewControllerSuffix length]) {
      pageViewName = [pageViewName substringToIndex:[pageViewName length] - [kMSACViewControllerSuffix length]];
    }

    // Track page if ready.
    if ([MSACAnalytics sharedInstance].available) {

      // Reset cached page.
      MSMissedPageViewName = nil;

      // Track page.
      [MSACAnalytics trackPage:pageViewName];
    } else {

      // Store the page name for retroactive tracking.
      // For instance if the service becomes enabled after the view appeared.
      MSMissedPageViewName = pageViewName;
    }
  }
}

@end

@implementation MSACAnalyticsCategory

+ (void)activateCategory {
  [MSViewController swizzleViewWillAppear];
}

+ (NSString *)missedPageViewName {
  return MSMissedPageViewName;
}

@end
