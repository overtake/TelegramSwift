// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

/**
 * Common schema metadata type identifiers.
 */
static const int kMSACLongMetadataTypeId = 4;
static const int kMSACDoubleMetadataTypeId = 6;
static const int kMSACDateTimeMetadataTypeId = 9;

/**
 * Minimum flush interval for channel.
 */
static NSUInteger const kMSACFlushIntervalMinimum = 3;

/**
 * Maximum flush interval for channel.
 */
static NSUInteger const kMSACFlushIntervalMaximum = 24 * 60 * 60;
