#import "TGPassportMRZ.h"

const NSUInteger TGPassportTD1Length = 30;
const NSUInteger TGPassportTD23Length = 44;
NSString *const TGPassportEmptyCharacter = @"<";

@implementation TGPassportMRZ
    /*
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

     */
    -(NSString *)description {
        return [NSString stringWithFormat:@"firstName: %@, lastName: %@, documentType: %@, documentSubtype: %@, issuingCountry: %@, documentNumber: %@, nationality: %@, birthDate: %@, gender: %@, expiryDate: %@", self.firstName, self.lastName, self.documentType, self.documentSubtype, self.issuingCountry, self.documentNumber, self.nationality, self.birthDate, self.gender, self.expiryDate];
    }
    
+ (instancetype)parseLines:(NSArray<NSString *> *)lines
    {
        if (lines.count == 2)
        {
            if (lines[0].length != TGPassportTD23Length || lines[1].length != TGPassportTD23Length)
            return nil;
            
            TGPassportMRZ *result = [[TGPassportMRZ alloc] init];
            result->_documentType = [lines[0] substringToIndex:1];
            result->_documentSubtype = [self cleanString:[lines[0] substringWithRange:NSMakeRange(1, 1)]];
            result->_issuingCountry = [self cleanString:[lines[0] substringWithRange:NSMakeRange(2, 3)]];
            
            NSCharacterSet *emptyCharacterSet = [NSCharacterSet characterSetWithCharactersInString:TGPassportEmptyCharacter];
            NSString *fullName = [[lines[0] substringWithRange:NSMakeRange(5, 39)] stringByTrimmingCharactersInSet:emptyCharacterSet];
            NSArray *names = [fullName componentsSeparatedByString:@"<<"];
            result->_lastName = [self nameString:names.firstObject];
            result->_firstName = [self nameString:names.lastObject];
            
            if ([result->_documentType isEqualToString:@"P"] && [result->_documentSubtype isEqualToString:@"N"] && [result->_issuingCountry isEqualToString:@"RUS"])
            {
                NSString *lastName = [self transliterateRussianMRZString:result->_lastName];
                result->_lastName = [self transliterateRussianName:lastName];
                NSString *firstName = [self transliterateRussianMRZString:result->_firstName];
                result->_firstName = [self transliterateRussianName:firstName];
            }
            
            NSString *documentNumber = [self ensureNumberString:[lines[1] substringToIndex:9]];
            NSInteger documentNumberCheck = [[self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(9, 1)]] integerValue];
            if ([self isDataValid:documentNumber check:documentNumberCheck])
            result->_documentNumber = documentNumber;
            
            result->_nationality = [lines[1] substringWithRange:NSMakeRange(10, 3)];
            NSString *birthDate = [self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(13, 6)]];
            NSInteger birthDateCheck = [[self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(19, 1)]] integerValue];
            if ([self isDataValid:birthDate check:birthDateCheck])
            result->_birthDate = [self dateFromString:birthDate];
            
            NSString *gender = [lines[1] substringWithRange:NSMakeRange(20, 1)];
            if ([gender isEqualToString:TGPassportEmptyCharacter])
            gender = nil;
            result->_gender = gender;
            
            NSString *expiryDate = [self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(21, 6)]];
            NSInteger expiryDateCheck = [[self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(27, 1)]] integerValue];
            if ([self isDataValid:expiryDate check:expiryDateCheck])
            result->_expiryDate = [self dateFromString:expiryDate];
            
            NSString *optional1 = [lines[1] substringWithRange:NSMakeRange(28, 14)];
            NSString *optional1CheckString = [self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(42, 1)]];
            NSInteger optional1CheckValue = [optional1CheckString isEqualToString:TGPassportEmptyCharacter] ? 0 : [optional1CheckString integerValue];
            if ([self isDataValid:optional1 check:optional1CheckValue])
            result->_optional1 = [self cleanString:optional1];
            
            NSString *data = [NSString stringWithFormat:@"%@%d%@%d%@%d%@%@", documentNumber, (int)documentNumberCheck, birthDate, (int)birthDateCheck, expiryDate, (int)expiryDateCheck, optional1, optional1CheckString];
            NSInteger dataCheck = [[self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(43, 1)]] integerValue];
            if ([self isDataValid:data check:dataCheck])
            return result;
        }
        else if (lines.count == 3)
        {
            if (lines[0].length != TGPassportTD1Length || lines[1].length != TGPassportTD1Length || lines[2].length != TGPassportTD1Length)
            return nil;
            
            TGPassportMRZ *result = [[TGPassportMRZ alloc] init];
            result->_documentType = [lines[0] substringToIndex:1];
            result->_documentSubtype = [self cleanString:[lines[0] substringWithRange:NSMakeRange(1, 1)]];
            result->_issuingCountry = [self cleanString:[lines[0] substringWithRange:NSMakeRange(2, 3)]];
            
            NSString *documentNumber = [self ensureNumberString:[lines[0] substringWithRange:NSMakeRange(5, 9)]];
            NSInteger documentNumberCheck = [[self ensureNumberString:[lines[0] substringWithRange:NSMakeRange(14, 1)]] integerValue];
            if ([self isDataValid:documentNumber check:documentNumberCheck])
            result->_documentNumber = documentNumber;
            
            NSString *optional1 = [lines[0] substringWithRange:NSMakeRange(15, 15)];
            result->_optional1 = [self cleanString:optional1];
            
            NSString *birthDate = [self ensureNumberString:[lines[1] substringToIndex:6]];
            NSInteger birthDateCheck = [[lines[1] substringWithRange:NSMakeRange(6, 1)] integerValue];
            if ([self isDataValid:birthDate check:birthDateCheck])
            result->_birthDate = [self dateFromString:birthDate];
            
            NSString *gender = [lines[1] substringWithRange:NSMakeRange(7, 1)];
            if ([gender isEqualToString:TGPassportEmptyCharacter])
            gender = nil;
            result->_gender = gender;
            
            NSString *expiryDate = [self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(8, 6)]];
            NSInteger expiryDateCheck = [[self ensureNumberString:[lines[1] substringWithRange:NSMakeRange(14, 1)]] integerValue];
            if ([self isDataValid:expiryDate check:expiryDateCheck])
            result->_expiryDate = [self dateFromString:expiryDate];
            
            result->_nationality = [lines[1] substringWithRange:NSMakeRange(15, 3)];
            
            NSString *optional2 = [lines[1] substringWithRange:NSMakeRange(18, 11)];
            result->_optional2 = optional2;
            
            NSCharacterSet *emptyCharacterSet = [NSCharacterSet characterSetWithCharactersInString:TGPassportEmptyCharacter];
            NSString *fullName = [self ensureAlphaString:lines[2]];
            fullName = [fullName stringByTrimmingCharactersInSet:emptyCharacterSet];
            NSArray *names = [fullName componentsSeparatedByString:@"<<"];
            result->_lastName = [self nameString:names.firstObject];
            result->_firstName = [self nameString:names.lastObject];
            
            return result;
        }
        return nil;
    }
    
+ (NSDateFormatter *)dateFormatter
    {
        static dispatch_once_t onceToken;
        static NSDateFormatter *dateFormatter;
        dispatch_once(&onceToken, ^
                      {
                          dateFormatter = [[NSDateFormatter alloc] init];
                          dateFormatter.dateFormat = @"YYMMdd";
                          dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                      });
        return dateFormatter;
    }
    
    
+ (NSDate *)dateFromString:(NSString *)string
    {
        return [[self dateFormatter] dateFromString:string];
    }
    
+ (NSString *)cleanString:(NSString *)string
    {
        return [string stringByReplacingOccurrencesOfString:TGPassportEmptyCharacter withString:@""];
    }
    
+ (NSString *)nameString:(NSString *)string
    {
        return [string stringByReplacingOccurrencesOfString:TGPassportEmptyCharacter withString:@" "];
    }
    
+ (NSString *)ensureNumberString:(NSString *)string
    {
        return [[[[string stringByReplacingOccurrencesOfString:@"O" withString:@"0"] stringByReplacingOccurrencesOfString:@"U" withString:@"0"] stringByReplacingOccurrencesOfString:@"Q" withString:@"0"] stringByReplacingOccurrencesOfString:@"J" withString:@"0"];
    }
    
+ (NSString *)ensureAlphaString:(NSString *)string
    {
        NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ<"];
        NSCharacterSet *invalidChars = [validChars invertedSet];
        
        string = [string stringByReplacingOccurrencesOfString:@"0" withString:@"O"];
        return  [self string:string byReplacingCharactersInSet:invalidChars withString:TGPassportEmptyCharacter];
    }
    
+ (NSString *)string:(NSString *)string byReplacingCharactersInSet:(NSCharacterSet *)charSet withString:(NSString *)aString {
    NSMutableString *s = [NSMutableString stringWithCapacity:string.length];
    for (NSUInteger i = 0; i < string.length; ++i) {
        unichar c = [string characterAtIndex:i];
        if (![charSet characterIsMember:c]) {
            [s appendFormat:@"%C", c];
        } else {
            [s appendString:aString];
        }
    }
    return s;
}
    
+ (NSString *)transliterateRussianMRZString:(NSString *)string
    {
        NSDictionary *map = @
        {
            @"A": @"А",
            @"B": @"Б",
            @"V": @"В",
            @"G": @"Г",
            @"D": @"Д",
            @"E": @"Е",
            @"2": @"Ё",
            @"J": @"Ж",
            @"Z": @"З",
            @"I": @"И",
            @"Q": @"Й",
            @"K": @"К",
            @"L": @"Л",
            @"M": @"М",
            @"N": @"Н",
            @"O": @"О",
            @"P": @"П",
            @"R": @"Р",
            @"S": @"С",
            @"T": @"Т",
            @"U": @"У",
            @"F": @"Ф",
            @"H": @"Х",
            @"C": @"Ц",
            @"3": @"Ч",
            @"4": @"Ш",
            @"W": @"Щ",
            @"X": @"Ъ",
            @"Y": @"Ы",
            @"9": @"Ь",
            @"6": @"Э",
            @"7": @"Ю",
            @"8": @"Я"
        };
        
        NSMutableString *result = [[NSMutableString alloc] init];
        [string enumerateSubstringsInRange:NSMakeRange(0, string.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop)
         {
             if (substring == nil)
             return;
             
             NSString *letter = map[substring];
             if (letter != nil)
             [result appendString:letter];
         }];
        return result;
    }
    
+ (NSString *)transliterateRussianName:(NSString *)string
    {
        NSDictionary *map = @
        {
            @"А": @"A",
            @"Б": @"B",
            @"В": @"V",
            @"Г": @"G",
            @"Д": @"D",
            @"Е": @"E",
            @"Ё": @"E",
            @"Ж": @"ZH",
            @"З": @"Z",
            @"И": @"I",
            @"Й": @"I",
            @"К": @"K",
            @"Л": @"L",
            @"М": @"M",
            @"Н": @"N",
            @"О": @"O",
            @"П": @"P",
            @"Р": @"R",
            @"С": @"S",
            @"Т": @"T",
            @"У": @"U",
            @"Ф": @"F",
            @"Х": @"KH",
            @"Ц": @"TS",
            @"Ч": @"CH",
            @"Ш": @"SH",
            @"Щ": @"SHCH",
            @"Ъ": @"IE",
            @"Ы": @"Y",
            @"Ь": @"",
            @"Э": @"E",
            @"Ю": @"IU",
            @"Я": @"IA"
        };
        
        NSMutableString *result = [[NSMutableString alloc] init];
        [string enumerateSubstringsInRange:NSMakeRange(0, string.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop)
         {
             if (substring == nil)
             return;
             
             NSString *letter = map[substring];
             if (letter != nil)
             [result appendString:letter];
         }];
        return result;
    }
    
+ (bool)isDataValid:(NSString *)data check:(NSInteger)check
    {
        int32_t sum = 0;
        uint8_t w[3] = { 7, 3, 1 };
        
        for (NSUInteger i = 0; i < data.length; i++)
        {
            unichar c = [data characterAtIndex:i];
            NSInteger d = 0;
            if (c >= '0' && c <= '9')
            d = c - '0';
            else if (c >= 'A' && c <= 'Z')
            d = (10 + c) - 'A';
            else if (c != '<')
            return false;
            
            sum += d * w[i % 3];
        }
        
        if (sum % 10 != check)
        return false;
        
        return true;
    }
    
    @end
