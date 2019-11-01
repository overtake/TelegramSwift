#ifndef HockeySDKEnums_h
#define HockeySDKEnums_h

/**
 *  HockeySDK Log Levels
 */
typedef NS_ENUM(NSUInteger, BITLogLevel) {
  /**
   *  Logging is disabled
   */
  BITLogLevelNone = 0,
  /**
   *  Only errors will be logged
   */
  BITLogLevelError = 1,
  /**
   *  Errors and warnings will be logged
   */
  BITLogLevelWarning = 2,
  /**
   *  Debug information will be logged
   */
  BITLogLevelDebug = 3,
  /**
   *  Logging will be very chatty
   */
  BITLogLevelVerbose = 4
};

typedef NSString *(^BITLogMessageProvider)(void);
typedef void (^BITLogHandler)(BITLogMessageProvider messageProvider, BITLogLevel logLevel, const char *file, const char *function, uint line);

#endif /* HockeySDKEnums_h */
