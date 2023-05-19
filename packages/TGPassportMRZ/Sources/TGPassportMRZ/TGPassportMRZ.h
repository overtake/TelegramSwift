#import <Foundation/Foundation.h>

@interface TGPassportMRZ : NSObject

@property (nonatomic, readonly) NSString *documentType;
@property (nonatomic, readonly) NSString *documentSubtype;
@property (nonatomic, readonly) NSString *issuingCountry;
@property (nonatomic, readonly) NSString *lastName;
@property (nonatomic, readonly) NSString *firstName;
@property (nonatomic, readonly) NSString *documentNumber;
@property (nonatomic, readonly) NSString *nationality;
@property (nonatomic, readonly) NSDate *birthDate;
@property (nonatomic, readonly) NSString *gender;
@property (nonatomic, readonly) NSDate *expiryDate;
@property (nonatomic, readonly) NSString *optional1;
@property (nonatomic, readonly) NSString *optional2;

+ (instancetype)parseLines:(NSArray *)lines;

@end

extern const NSUInteger TGPassportTD1Length;
extern const NSUInteger TGPassportTD23Length;
