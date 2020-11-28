// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@class MSACAnalytics;
@class MSACEventLog;
@class MSACPageLog;

@protocol MSACAnalyticsDelegate <NSObject>

@optional

/**
 * Callback method that will be called before each event log is sent to the server.
 *
 * @param analytics The instance of MSACAnalytics.
 * @param eventLog The event log that will be sent.
 */
- (void)analytics:(MSACAnalytics *)analytics willSendEventLog:(MSACEventLog *)eventLog;

/**
 * Callback method that will be called in case the SDK was able to send an event log to the server. Use this method to provide custom
 * behavior.
 *
 * @param analytics The instance of MSACAnalytics.
 * @param eventLog The event log that App Center sent.
 */
- (void)analytics:(MSACAnalytics *)analytics didSucceedSendingEventLog:(MSACEventLog *)eventLog;

/**
 * Callback method that will be called in case the SDK was unable to send an event log to the server.
 *
 * @param analytics The instance of MSACAnalytics.
 * @param eventLog The event log that App Center tried to send.
 * @param error The error that occurred.
 */
- (void)analytics:(MSACAnalytics *)analytics didFailSendingEventLog:(MSACEventLog *)eventLog withError:(NSError *)error;

/**
 * Callback method that will be called before each page log is sent to the server.
 *
 * @param analytics The instance of MSACAnalytics.
 * @param pageLog The page log that will be sent.
 */
- (void)analytics:(MSACAnalytics *)analytics willSendPageLog:(MSACPageLog *)pageLog;

/**
 * Callback method that will be called in case the SDK was able to send a page log to the server. Use this method to provide custom
 * behavior.
 *
 * @param analytics The instance of MSACAnalytics.
 * @param pageLog The page log that App Center sent.
 */
- (void)analytics:(MSACAnalytics *)analytics didSucceedSendingPageLog:(MSACPageLog *)pageLog;

/**
 * Callback method that will be called in case the SDK was unable to send a page log to the server.
 *
 * @param analytics The instance of MSACAnalytics.
 * @param pageLog The page log that App Center tried to send.
 * @param error The error that occurred.
 */
- (void)analytics:(MSACAnalytics *)analytics didFailSendingPageLog:(MSACPageLog *)pageLog withError:(NSError *)error;

@end
