//
//  SyntaxHighligher.m
//  CodeSyntax
//
//  Created by Mike Renoir on 26.10.2023.
//

#import "Syntaxer.h"
#import "SyntaxHighlighter.h"
#import "TokenList.h"
#import <Cocoa/Cocoa.h>


NSDictionary<NSString *, NSColor *> *light = @{
    @"comment": [NSColor colorWithDeviceRed:112/255.0 green:128/255.0 blue:144/255.0 alpha:1.0],
    @"block-comment": [NSColor colorWithDeviceRed:112/255.0 green:128/255.0 blue:144/255.0 alpha:1.0],
    @"prolog": [NSColor colorWithDeviceRed:112/255.0 green:128/255.0 blue:144/255.0 alpha:1.0],
    @"doctype": [NSColor colorWithDeviceRed:112/255.0 green:128/255.0 blue:144/255.0 alpha:1.0],
    @"cdata": [NSColor colorWithDeviceRed:112/255.0 green:128/255.0 blue:144/255.0 alpha:1.0],
    @"punctuation": [NSColor colorWithDeviceRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0],
    @"property": [NSColor colorWithDeviceRed:153/255.0 green:0/255.0 blue:85/255.0 alpha:1.0],
    @"tag": [NSColor colorWithDeviceRed:153/255.0 green:0/255.0 blue:85/255.0 alpha:1.0],
    @"boolean": [NSColor colorWithDeviceRed:153/255.0 green:0/255.0 blue:85/255.0 alpha:1.0],
    @"number": [NSColor colorWithDeviceRed:153/255.0 green:0/255.0 blue:85/255.0 alpha:1.0],
    @"constant": [NSColor colorWithDeviceRed:153/255.0 green:0/255.0 blue:85/255.0 alpha:1.0],
    @"symbol": [NSColor colorWithDeviceRed:153/255.0 green:0/255.0 blue:85/255.0 alpha:1.0],
    @"deleted": [NSColor colorWithDeviceRed:153/255.0 green:0/255.0 blue:85/255.0 alpha:1.0],
    @"selector": [NSColor colorWithDeviceRed:102/255.0 green:153/255.0 blue:0/255.0 alpha:1.0],
    @"attr-name": [NSColor colorWithDeviceRed:102/255.0 green:153/255.0 blue:0/255.0 alpha:1.0],
    @"string": [NSColor colorWithDeviceRed:102/255.0 green:153/255.0 blue:0/255.0 alpha:1.0],
    @"char": [NSColor colorWithDeviceRed:102/255.0 green:153/255.0 blue:0/255.0 alpha:1.0],
    @"builtin": [NSColor colorWithDeviceRed:102/255.0 green:153/255.0 blue:0/255.0 alpha:1.0],
    @"inserted": [NSColor colorWithDeviceRed:102/255.0 green:153/255.0 blue:0/255.0 alpha:1.0],
    @"operator": [NSColor colorWithDeviceRed:154/255.0 green:174/255.0 blue:108/255.0 alpha:1.0],
    @"entity": [NSColor colorWithDeviceRed:154/255.0 green:174/255.0 blue:108/255.0 alpha:1.0],
    @"url": [NSColor colorWithDeviceRed:154/255.0 green:174/255.0 blue:108/255.0 alpha:1.0],
    @"atrule": [NSColor colorWithDeviceRed:0/255.0 green:119/255.0 blue:170/255.0 alpha:1.0],
    @"attr-value": [NSColor colorWithDeviceRed:0/255.0 green:119/255.0 blue:170/255.0 alpha:1.0],
    @"keyword": [NSColor colorWithDeviceRed:0/255.0 green:119/255.0 blue:170/255.0 alpha:1.0],
    @"function-definition": [NSColor colorWithDeviceRed:0/255.0 green:119/255.0 blue:170/255.0 alpha:1.0],
    @"class-name": [NSColor colorWithDeviceRed:221/255.0 green:74/255.0 blue:104/255.0 alpha:1.0],
};

NSDictionary<NSString *, NSColor *> *dark = @{
    @"comment": [NSColor colorWithDeviceRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0],
    @"block-comment": [NSColor colorWithDeviceRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0],
    @"prolog": [NSColor colorWithDeviceRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0],
    @"doctype": [NSColor colorWithDeviceRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0],
    @"cdata": [NSColor colorWithDeviceRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0],
    @"punctuation": [NSColor colorWithDeviceRed:204/255.0 green:204/255.0 blue:204/255.0 alpha:1.0],
    @"property": [NSColor colorWithDeviceRed:248/255.0 green:197/255.0 blue:85/255.0 alpha:1.0],
    @"tag": [NSColor colorWithDeviceRed:226/255.0 green:119/255.0 blue:122/255.0 alpha:1.0],
    @"boolean": [NSColor colorWithDeviceRed:240/255.0 green:141/255.0 blue:73/255.0 alpha:1.0],
    @"number": [NSColor colorWithDeviceRed:240/255.0 green:141/255.0 blue:73/255.0 alpha:1.0],
    @"constant": [NSColor colorWithDeviceRed:248/255.0 green:197/255.0 blue:85/255.0 alpha:1.0],
    @"symbol": [NSColor colorWithDeviceRed:248/255.0 green:197/255.0 blue:85/255.0 alpha:1.0],
    @"deleted": [NSColor colorWithDeviceRed:226/255.0 green:119/255.0 blue:122/255.0 alpha:1.0],
    @"selector": [NSColor colorWithDeviceRed:204/255.0 green:153/255.0 blue:205/255.0 alpha:1.0],
    @"attr-name": [NSColor colorWithDeviceRed:226/255.0 green:119/255.0 blue:122/255.0 alpha:1.0],
    @"string": [NSColor colorWithDeviceRed:126/255.0 green:198/255.0 blue:153/255.0 alpha:1.0],
    @"char": [NSColor colorWithDeviceRed:126/255.0 green:198/255.0 blue:153/255.0 alpha:1.0],
    @"builtin": [NSColor colorWithDeviceRed:204/255.0 green:153/255.0 blue:205/255.0 alpha:1.0],
    @"inserted": [NSColor colorWithDeviceRed:102/255.0 green:153/255.0 blue:0/255.0 alpha:1.0],
    @"operator": [NSColor colorWithDeviceRed:103/255.0 green:205/255.0 blue:204/255.0 alpha:1.0],
    @"entity": [NSColor colorWithDeviceRed:103/255.0 green:205/255.0 blue:204/255.0 alpha:1.0],
    @"url": [NSColor colorWithDeviceRed:103/255.0 green:205/255.0 blue:204/255.0 alpha:1.0],
    @"atrule": [NSColor colorWithDeviceRed:204/255.0 green:153/255.0 blue:205/255.0 alpha:1.0],
    @"attr-value": [NSColor colorWithDeviceRed:126/255.0 green:198/255.0 blue:153/255.0 alpha:1.0],
    @"keyword": [NSColor colorWithDeviceRed:204/255.0 green:153/255.0 blue:205/255.0 alpha:1.0],
    @"function-definition": [NSColor colorWithDeviceRed:240/255.0 green:141/255.0 blue:73/255.0 alpha:1.0],
    @"class-name": [NSColor colorWithDeviceRed:248/255.0 green:197/255.0 blue:85/255.0 alpha:1.0],
};

std::string dataToString(NSData *nsData) {
    const void *dataBytes = [nsData bytes];
    NSUInteger dataLength = [nsData length];
    
    return std::string(static_cast<const char*>(dataBytes), dataLength);
}

NSString* stringViewToNSString(std::string_view sv) {
    std::string cppString(sv.data(), sv.length());
    return [NSString stringWithUTF8String:cppString.c_str()];
}

NSString* stringToNSString(const std::string& cppString) {
    return [NSString stringWithUTF8String:cppString.c_str()];
}

@implementation SyntaxterTheme

-(id)initWithDark:(BOOL)dark textColor:(NSColor *)textColor textFont:(NSFont *)textFont italicFont:(NSFont *)italicFont mediumFont:(NSFont *)mediumFont {
    if (self = [super init]) {
        _dark = dark;
        _textColor = textColor;
        _textFont = textFont;
        _italicFont = italicFont;
        _mediumFont = mediumFont;
    }
    return self;
}

@end


@interface Brush : NSObject
@property (nonatomic, strong) NSFont *font;
@property (nonatomic, strong) NSColor *color;
@end

@implementation Brush

-(id)initWith:(NSFont *)font color:(NSColor *)color {
    if (self = [super init]) {
        _font = font;
        _color = color;
    }
    return self;
}

@end


void applyString(NSString * string, NSMutableAttributedString * attributed, Brush *brush) {
    if (string != nil) {
        NSMutableAttributedString *substring = [[NSMutableAttributedString alloc] initWithString: string];
        NSRange range = NSMakeRange(0, string.length);
        [substring addAttribute:NSForegroundColorAttributeName value: brush.color range:range];
        [substring addAttribute:NSFontAttributeName value:brush.font range:range];
        [attributed appendAttributedString:substring];
    }
}

Brush *makeBrush(std::string alias, std::string type, SyntaxterTheme * theme, Brush *previous) {
    NSString * aliasKey = stringToNSString(alias);
    NSString * typeKey = stringToNSString(type);
    
    
    
    NSDictionary<NSString *, NSColor *> *colors;
    if (theme.dark) {
        colors = dark;
    } else {
        colors = light;
    }
    
    NSColor *color = colors[aliasKey];
    NSFont *font = theme.textFont;
    
    if (color == nil) {
        color = colors[typeKey];
    }
    if (color == nil) {
        color = previous.color;
    }
    if (color == nil) {
        color = theme.textColor;
    }
    if ([typeKey isEqualToString:@"bold"]) {
        font = theme.mediumFont;
    }
    if ([typeKey isEqualToString:@"italic"]) {
        font = theme.italicFont;
    }
    
    if (previous != nil) {
        font = previous.font;
    }
    
    return [[Brush alloc] initWith:font color:color];
}

@interface Syntaxer ()
@property (atomic) std::shared_ptr<SyntaxHighlighter> m_highlighter;
@end

@implementation Syntaxer
-(id)init:(NSData *)grammar {
    if (self = [super init]) {
        std::string text = dataToString(grammar);
        _m_highlighter = std::make_shared<SyntaxHighlighter>(text);
    }
    return self;
}

-(NSAttributedString *)syntax:(NSString *)code language: (NSString *)language theme: (SyntaxterTheme *) theme {
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
    std::string c_code = code.UTF8String;
    std::string c_language = language.UTF8String;

    TokenList tokens = _m_highlighter->tokenize(c_code, c_language);
    for (auto it = tokens.begin(); it != tokens.end(); ++it)
    {
        auto& node = *it;
        Brush *brush;
        if (node.isSyntax()) {
            const auto& child = dynamic_cast<const Syntax&>(node);
            brush = makeBrush(child.alias(), child.type(), theme, nil);
        } else {
            brush = makeBrush("", "", theme, nil);
        }
        [self paint:node string:string brush:brush theme: theme];
    }
    return string;
}


- (void) paint:(const TokenListNode &)node string: (NSMutableAttributedString *) string brush:(Brush *)upperBrash theme: (SyntaxterTheme *) theme {
    if (node.isSyntax())
    {
        const auto& child = dynamic_cast<const Syntax&>(node);
        
        for (auto j = child.begin(); j != child.end(); ++j)
        {
            auto& innerNode = *j;
            if (innerNode.isSyntax())
            {
                const auto& innerChild = dynamic_cast<const Syntax&>(innerNode);
                Brush *brush = makeBrush(innerChild.alias(), innerChild.type(), theme, upperBrash);
                [self paint:innerNode string:string brush:brush theme: theme];
            } else {
                const auto& innerChild = dynamic_cast<const Text&>(innerNode);
                applyString(stringViewToNSString(innerChild.value()), string, upperBrash);
            }
        }
    } else {
        const auto& child = dynamic_cast<const Text&>(node);
        applyString(stringViewToNSString(child.value()), string, upperBrash);
    }
}


@end
