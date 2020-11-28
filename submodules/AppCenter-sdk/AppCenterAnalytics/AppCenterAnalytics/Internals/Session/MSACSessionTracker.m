// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACSessionTracker.h"
#import "MSACAnalyticsInternal.h"
#import "MSACSessionContext.h"
#import "MSACSessionTrackerPrivate.h"
#import "MSACStartServiceLog.h"
#import "MSACStartSessionLog.h"

static NSTimeInterval const kMSACSessionTimeOut = 20;
static NSString *const kMSACPastSessionsKey = @"PastSessions";

@interface MSACSessionTracker ()

/**
 * Check if current session has timed out.
 *
 * @return YES if current session has timed out, NO otherwise.
 */
- (BOOL)hasSessionTimedOut;

@end

@implementation MSACSessionTracker

- (instancetype)init {
  if ((self = [super init])) {
    _sessionTimeout = kMSACSessionTimeOut;
    _context = [MSACSessionContext sharedInstance];

    // Remove old session history from previous SDK versions.
    [MSAC_APP_CENTER_USER_DEFAULTS removeObjectForKey:kMSACPastSessionsKey];

    // Session tracking is not started by default.
    _started = NO;
  }
  return self;
}

- (void)renewSessionId {
  @synchronized(self) {
    if (self.started) {

      // Check if new session id is required.
      if ([self.context sessionId] == nil || [self hasSessionTimedOut]) {
        NSString *sessionId = MSAC_UUID_STRING;
        [self.context setSessionId:sessionId];
        MSACLogInfo([MSACAnalytics logTag], @"New session ID: %@", sessionId);

        // Create a start session log.
        MSACStartSessionLog *log = [[MSACStartSessionLog alloc] init];
        log.sid = sessionId;
        [self.delegate sessionTracker:self processLog:log];
      }
    }
  }
}

- (void)start {
  if (!self.started) {
    self.started = YES;

    // Request a new session id depending on the application state.
    MSACApplicationState state = [MSACUtility applicationState];
    if (state == MSACApplicationStateInactive || state == MSACApplicationStateActive) {
      [self renewSessionId];
    }

    // Hookup to application events.
    [MSAC_NOTIFICATION_CENTER addObserver:self
                                 selector:@selector(applicationDidEnterBackground)
#if TARGET_OS_OSX
                                     name:NSApplicationDidResignActiveNotification
#else
                                     name:UIApplicationDidEnterBackgroundNotification
#endif
                                   object:nil];
    [MSAC_NOTIFICATION_CENTER addObserver:self
                                 selector:@selector(applicationWillEnterForeground)
#if TARGET_OS_OSX
                                     name:NSApplicationWillBecomeActiveNotification
#else
                                     name:UIApplicationWillEnterForegroundNotification
#endif
                                   object:nil];
  }
}

- (void)stop {
  if (self.started) {
    [MSAC_NOTIFICATION_CENTER removeObserver:self];
    self.started = NO;
    [self.context setSessionId:nil];
  }
}

- (void)dealloc {
  [MSAC_NOTIFICATION_CENTER removeObserver:self];
}

#pragma mark - private methods

- (BOOL)hasSessionTimedOut {

  @synchronized(self) {
    NSDate *now = [NSDate date];

    // Verify if a log has already been sent and if it was sent a longer time ago than the session timeout.
    BOOL noLogSentForLong = !self.lastCreatedLogTime || [now timeIntervalSinceDate:self.lastCreatedLogTime] >= self.sessionTimeout;

    // FIXME: There is no life cycle for app extensions yet so ignoring the background tests for now.
    if (MSAC_IS_APP_EXTENSION)
      return noLogSentForLong;

    // Verify if app is currently in the background for a longer time than the session timeout.
    BOOL isBackgroundForLong = (self.lastEnteredBackgroundTime && self.lastEnteredForegroundTime) &&
                               ([self.lastEnteredBackgroundTime compare:self.lastEnteredForegroundTime] == NSOrderedDescending) &&
                               ([now timeIntervalSinceDate:self.lastEnteredBackgroundTime] >= self.sessionTimeout);

    // Verify if app was in the background for a longer time than the session timeout time.
    BOOL wasBackgroundForLong =
        (self.lastEnteredBackgroundTime)
            ? [self.lastEnteredForegroundTime timeIntervalSinceDate:self.lastEnteredBackgroundTime] >= self.sessionTimeout
            : false;
    return noLogSentForLong && (isBackgroundForLong || wasBackgroundForLong);
  }
}

- (void)applicationDidEnterBackground {
  self.lastEnteredBackgroundTime = [NSDate date];
}

- (void)applicationWillEnterForeground {
  self.lastEnteredForegroundTime = [NSDate date];

  // Trigger session renewal.
  [self renewSessionId];
}

#pragma mark - MSACChannelDelegate

- (void)channel:(id<MSACChannelProtocol>)__unused channel prepareLog:(id<MSACLog>)log {

  /*
   * Start session log is created in this method, therefore, skip in order to avoid infinite loop. Also skip start service log as it's
   * always sent and should not trigger a session.
   */
  if ([((NSObject *)log) isKindOfClass:[MSACStartSessionLog class]] || [((NSObject *)log) isKindOfClass:[MSACStartServiceLog class]])
    return;

  // If the log requires session Id.
  if (![(NSObject *)log conformsToProtocol:@protocol(MSACNoAutoAssignSessionIdLog)]) {
    log.sid = [self.context sessionId];
  }

  // Update last created log time stamp.
  self.lastCreatedLogTime = [NSDate date];
}

@end
