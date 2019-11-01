@class BITCrashManager;
@class BITFeedbackManager;
@class BITMetricsManager;
@protocol BITHockeyManagerDelegate;

#import "HockeySDK.h"

/**
 The HockeySDK manager. Responsible for setup and management of all components
 
 This is the principal SDK class. It represents the entry point for the HockeySDK. The main promises of the class are initializing the SDK
 modules, providing access to global properties and to all modules. Initialization is divided into several distinct phases:
 
 1. Setup the [HockeyApp](http://hockeyapp.net/) app identifier and the optional delegate: This is the least required information on setting up the SDK and using it. It does some simple validation of the app identifier.
 2. Provides access to the SDK module `BITCrashManager`. This way all modules can be further configured to personal needs, if the defaults don't fit the requirements.
 3. Configure each module.
 4. Start up all modules.
 
 The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on startup can also be caught and each module executes other code with a delay some seconds. This ensures that applicationDidFinishLaunching will process as fast as possible and the SDK will not block the startup sequence resulting in a possible kill by the watchdog process.
 
 All modules do **NOT** show any user interface if the module is not activated or not integrated.
 `BITCrashManager`: Shows an alert on startup asking the user if he/she agrees on sending the crash report, if `[BITCrashManager autoSubmitCrashReport]` is enabled (default)
 
 Example:
 
     [[BITHockeyManager sharedHockeyManager]
       configureWithIdentifier:@"<AppIdentifierFromHockeyApp>"];
     [[BITHockeyManager sharedHockeyManager] startManager];
 
 @warning The SDK is **NOT** thread safe and has to be set up on the main thread!
 
 @warning You should **NOT** change any module configuration after calling `startManager`!
 
 */
@interface BITHockeyManager : NSObject

#pragma mark - Public Methods

///-----------------------------------------------------------------------------
/// @name Initialization
///-----------------------------------------------------------------------------

/**
 *  Returns the shared manager object
 *
 *  @return A singleton BITHockeyManager instance ready use
 */
+ (BITHockeyManager *)sharedHockeyManager;

/**
 * Initializes the manager with a particular app identifier, company name and delegate
 *
 * Initialize the manager with a HockeyApp app identifier.
 *
 * @see BITCrashManagerDelegate
 * @see startManager
 * @see configureWithIdentifier:delegate:
 * @param appIdentifier The app identifier that should be used.
 */
- (void)configureWithIdentifier:(NSString *)appIdentifier;

/**
 * Initializes the manager with a particular app identifier, company name and delegate
 *
 * Initialize the manager with a HockeyApp app identifier and assign the class that
 * implements the optional protocol `BITCrashManagerDelegate`.
 *
 * @see BITCrashManagerDelegate
 * @see startManager
 * @see configureWithIdentifier:
 * @param appIdentifier The app identifier that should be used.
 * @param delegate `nil` or the class implementing the optional protocols
 */
- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id <BITHockeyManagerDelegate>) delegate;

/**
 * Initializes the manager with a particular app identifier, company name and delegate
 *
 * Initialize the manager with a HockeyApp app identifier and assign the class that
 * implements the required protocol `BITCrashManagerDelegate`.
 *
 * @see BITCrashManagerDelegate
 * @see startManager
 * @see configureWithIdentifier:
 * @see configureWithIdentifier:delegate:
 * @param appIdentifier The app identifier that should be used.
 * @param companyName `nil` or the company name, this is not used anywhere any longer.
 * @param delegate `nil` or the class implementing the required protocols
 */
- (void)configureWithIdentifier:(NSString *)appIdentifier companyName:(NSString *)companyName delegate:(id <BITHockeyManagerDelegate>) delegate __attribute__((deprecated("Use configureWithIdentifier:delegate: instead")));

/**
 * Starts the manager and runs all modules
 *
 * Call this after configuring the manager and setting up all modules.
 *
 * @see configureWithIdentifier:
 * @see configureWithIdentifier:delegate:
 */
- (void)startManager;


#pragma mark - Public Properties

///-----------------------------------------------------------------------------
/// @name General
///-----------------------------------------------------------------------------


/**
 * Set the delegate
 *
 * Defines the class that implements the optional protocol `BITHockeyManagerDelegate`.
 *
 * @see BITHockeyManagerDelegate
 * @see BITCrashManagerDelegate
 */
@property (nonatomic, weak) id<BITHockeyManagerDelegate> delegate;


///-----------------------------------------------------------------------------
/// @name Modules
///-----------------------------------------------------------------------------


/**
 * Defines the server URL to send data to or request data from
 *
 * By default this is set to the HockeyApp servers and there rarely should be a
 * need to modify that.
 * Please be aware that the URL for `BITMetricsManager` needs to be set separately
 * as this class uses a different endpoint!
 */
@property (nonatomic, copy) NSString *serverURL;

/**
 * Reference to the initialized BITCrashManager module
 *
 * Returns the BITCrashManager instance initialized by BITHockeyManager
 *
 * @see configureWithIdentifier:
 * @see configureWithIdentifier:delegate:
 * @see startManager
 * @see disableCrashManager
 */
@property (nonatomic, strong, readonly) BITCrashManager *crashManager;


/**
 * Flag the determines whether the Crash Manager should be disabled
 *
 * If this flag is enabled, then crash reporting is disabled and no crashes will
 * be send.
 *
 * Please note that the Crash Manager will be initialized anyway!
 *
 * *Default*: _NO_
 * @see crashManager
 */
@property (nonatomic, getter = isCrashManagerDisabled) BOOL disableCrashManager;


/**
 Reference to the initialized BITFeedbackManager module
 
 Returns the BITFeedbackManager instance initialized by BITHockeyManager
 
 @see configureWithIdentifier:delegate:
 @see startManager
 @see disableFeedbackManager
 */
@property (nonatomic, strong, readonly) BITFeedbackManager *feedbackManager;


/**
 Flag the determines whether the Feedback Manager should be disabled
 
 If this flag is enabled, then letting the user give feedback and
 get responses will be turned off!
 
 Please note that the Feedback Manager will be initialized anyway!
 
 *Default*: _NO_
 @see feedbackManager
 */
@property (nonatomic, getter = isFeedbackManagerDisabled) BOOL disableFeedbackManager;


/**
 Reference to the initialized BITMetricsManager module
 
 Returns the BITMetricsManager instance initialized by BITHockeyManager
 */
@property (nonatomic, strong, readonly) BITMetricsManager *metricsManager;

/**
 Flag the determines whether the BITMetricsManager should be disabled
 
 If this flag is enabled, then sending metrics data such as sessions and users
 will be turned off!
 
 Please note that the BITMetricsManager instance will be initialized anyway!
  
 *Default*: _NO_
 @see metricsManager
 */
@property (nonatomic, getter = isMetricsManagerDisabled) BOOL disableMetricsManager;


///-----------------------------------------------------------------------------
/// @name Configuration
///-----------------------------------------------------------------------------


/** Set the userid that should used in the SDK components
 
 Right now this is used by the `BITCrashManager` to attach to a crash report.
 `BITFeedbackManager` uses it too for assigning the user to a discussion thread.
 
 The value can be set at any time and will be stored in the keychain on the current
 device only! To delete the value from the keychain set the value to `nil`.
 
 This property is optional and can be used as an alternative to the delegate. If you
 want to define specific data for each component, use the delegate instead which does
 overwrite the values set by this property.
 
 @warning When returning a non nil value, crash reports are not anonymous any more
 and the crash alerts will not show the word "anonymous"!
 
 @warning This property needs to be set before calling `startManager` to be considered
 for being added to crash reports as meta data.
 
 @see [BITHockeyManagerDelegate userIDForHockeyManager:componentManager:]
 @see setUserName:
 @see setUserEmail:
 
 @param userID NSString value for the userID
 */
- (void)setUserID:(NSString *)userID;


/** Set the user name that should used in the SDK components
 
 Right now this is used by the `BITCrashManager` to attach to a crash report.
 `BITFeedbackManager` uses it too for assigning the user to a discussion thread.
 
 The value can be set at any time and will be stored in the keychain on the current
 device only! To delete the value from the keychain set the value to `nil`.
 
 This property is optional and can be used as an alternative to the delegate. If you
 want to define specific data for each component, use the delegate instead which does
 overwrite the values set by this property.
 
 @warning When returning a non nil value, crash reports are not anonymous any more
 and the crash alerts will not show the word "anonymous"!
 
 @warning This property needs to be set before calling `startManager` to be considered
 for being added to crash reports as meta data.

 @see [BITHockeyManagerDelegate userNameForHockeyManager:componentManager:]
 @see setUserID:
 @see setUserEmail:
 
 @param userName NSString value for the userName
 */
- (void)setUserName:(NSString *)userName;


/** Set the users email address that should used in the SDK components
 
 Right now this is used by the `BITCrashManager` to attach to a crash report.
 `BITFeedbackManager` uses it too for assigning the user to a discussion thread.
 
 The value can be set at any time and will be stored in the keychain on the current
 device only! To delete the value from the keychain set the value to `nil`.
 
 This property is optional and can be used as an alternative to the delegate. If you
 want to define specific data for each component, use the delegate instead which does
 overwrite the values set by this property.
 
 @warning When returning a non nil value, crash reports are not anonymous any more
 and the crash alerts will not show the word "anonymous"!
 
 @warning This property needs to be set before calling `startManager` to be considered
 for being added to crash reports as meta data.

 @see [BITHockeyManagerDelegate userEmailForHockeyManager:componentManager:]
 @see setUserID:
 @see setUserName:
 
 @param userEmail NSString value for the userEmail
 */
- (void)setUserEmail:(NSString *)userEmail;


///-----------------------------------------------------------------------------
/// @name Debug Logging
///-----------------------------------------------------------------------------

/**
 This property is used indicate the amount of verboseness and severity for which
 you want to see log messages in the console.
 */
@property (nonatomic, assign) BITLogLevel logLevel;

/**
 Flag that determines whether additional logging output should be generated
 by the manager and all modules.
 
 This is ignored if the app is running in the App Store and reverts to the
 default value in that case.
 
 @warning This property needs to be set before calling `startManager`
 
 *Default*: _NO_
 */
@property (nonatomic, assign, getter=isDebugLogEnabled) BOOL debugLogEnabled DEPRECATED_MSG_ATTRIBUTE("Use logLevel instead!");

/**
 Set a custom block that handles all the log messages that are emitted from the SDK.
 
 You can use this to reroute the messages that would normally be logged by `NSLog();`
 to your own custom logging framework.
 
 An example of how to do this with NSLogger:
 
 ```
 [[BITHockeyManager sharedHockeyManager] setLogHandler:^(BITLogMessageProvider messageProvider, BITLogLevel logLevel, const char *file, const char *function, uint line) {
 LogMessageRawF(file, (int)line, function, @"HockeySDK", (int)logLevel-1, messageProvider());
 }];
 ```
 
 or with CocoaLumberjack:
 
 ```
 [[BITHockeyManager sharedHockeyManager] setLogHandler:^(BITLogMessageProvider messageProvider, BITLogLevel logLevel, const char *file, const char *function, uint line) {
 [DDLog log:YES message:messageProvider() level:ddLogLevel flag:(DDLogFlag)(1 << (logLevel-1)) context:<#CocoaLumberjackContext#> file:file function:function line:line tag:nil];
 }];
 ```
 
 @param logHandler The block of type BITLogHandler that will process all logged messages.
 */
- (void)setLogHandler:(BITLogHandler)logHandler;


///-----------------------------------------------------------------------------
/// @name Integration test
///-----------------------------------------------------------------------------

/**
 Pings the server with the HockeyApp app identifiers used for initialization
 
 Call this method once for debugging purposes to test if your SDK setup code
 reaches the server successfully.
 
 Once invoked, check the apps page on HockeyApp for a verification.
 */
- (void)testIdentifier;


@end
