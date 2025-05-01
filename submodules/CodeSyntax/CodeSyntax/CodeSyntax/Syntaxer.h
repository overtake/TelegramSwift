//
//  SyntaxHighligher.h
//  CodeSyntax
//
//  Created by Mike Renoir on 26.10.2023.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface SyntaxterTheme : NSObject
@property (nonatomic, assign) BOOL dark;
@property (nonatomic, strong) NSColor *textColor;
@property (nonatomic, strong) NSFont *textFont;
@property (nonatomic, strong) NSFont *italicFont;
@property (nonatomic, strong) NSFont *mediumFont;
@property (nonatomic, strong) NSDictionary<NSString *, NSColor *> * colors;
-(id)initWithDark:(BOOL)dark textColor:(NSColor *)textColor textFont:(NSFont *)textFont italicFont:(NSFont *)italicFont mediumFont:(NSFont *) mediumFont themeKeys: (NSDictionary<NSString *, NSColor *> *)colors;
@end

@interface Syntaxer : NSObject
-(id)init:(NSData *)grammar;
-(NSAttributedString *)syntax:(NSString *)code language: (NSString *)language theme: (SyntaxterTheme *) theme;



@end

