#import <Cocoa/Cocoa.h>

//! Project version number for crc32mac.
FOUNDATION_EXPORT double Crc32VersionNumber;

//! Project version string for crc32mac.
FOUNDATION_EXPORT const unsigned char Crc32VersionString[];

uint32_t Crc32(const void *bytes, int length);
