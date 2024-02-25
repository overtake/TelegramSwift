//
//  TGModernGrowingTextView.h
//  Telegram
//
//  Created by keepcoder on 12/07/16.
//  Copyright © 2016 keepcoder. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TGInputTextTag.h"

extern NSString * _Nonnull const TGCustomLinkAttributeName;
extern NSString * _Nonnull const TGSpoilerAttributeName;
extern NSString * _Nonnull const TGAnimatedEmojiAttributeName;
extern NSString * _Nonnull const TGEmojiHolderAttributeName;
extern NSString * _Nonnull const TGQuoteAttributeName;
extern NSString * _Nonnull const QuoteAttributeName;


typedef NS_ENUM(NSInteger, TGTextInputTagId) {
    inputTagIdSpoiler = -1,
    inputTagIdEmojiHolder = -2
};

@class TGModernGrowingTextView;

@interface MarkdownUndoItem : NSObject
@property (nonatomic, strong) NSAttributedString *was;
@property (nonatomic, strong) NSAttributedString *be;
@property (nonatomic, assign) NSRange inRange;
-(id)initWithAttributedString:(NSAttributedString *)was be: (NSAttributedString *)be inRange:(NSRange)inRange;
@end


@interface SimpleUndoItem : NSObject
@property (nonatomic, strong) NSAttributedString *was;
@property (nonatomic, strong) NSAttributedString *be;
@property (nonatomic, assign) NSRange wasRange;
@property (nonatomic, assign) NSRange beRange;
-(id)initWithAttributedString:(NSAttributedString *)was be: (NSAttributedString *)be wasRange:(NSRange)wasRange beRange:(NSRange)beRange;
@end

@protocol TGModernGrowingDelegate <NSObject>

-(void) textViewHeightChanged:(CGFloat)height animated:(BOOL)animated;
-(BOOL) textViewEnterPressed:(NSEvent * __nonnull)event;
-(void) textViewTextDidChange:(NSString * __nonnull)string;
-(void) textViewTextDidChangeSelectedRange:(NSRange)range;
-(BOOL)textViewDidPaste:(NSPasteboard * __nonnull)pasteboard;
-(int)maxCharactersLimit:(TGModernGrowingTextView *)textView;

-(NSSize)textViewSize:(TGModernGrowingTextView *)textView;
-(BOOL)textViewIsTypingEnabled;

@optional
- (void)textViewNeedClose:(id __nonnull)textView;
- (BOOL)canTransformInputText;
- (BOOL)supportContinuityCamera;
- (void)responderDidUpdate;
- (void)textViewDidReachedLimit:(id __nonnull)textView;
- (void)makeUrlOfRange: (NSRange)range;
- (void)makeQuoteOfRange: (NSRange)range;
- (BOOL)copyTextWithRTF:(NSAttributedString *)rtf;
- (NSArray<NSTouchBarItemIdentifier> *)textView:(NSTextView *)textView shouldUpdateTouchBarItemIdentifiers:(NSArray<NSTouchBarItemIdentifier> *)identifiers;
@end


void setInputLocalizationFunc(NSString* _Nonnull (^ _Nonnull localizationF)(NSString * _Nonnull key));
void setTextViewEnableTouchBar(BOOL enableTouchBar);

@interface TGGrowingTextView : NSTextView<NSServicesMenuRequestor>
@property (nonatomic,weak) id <TGModernGrowingDelegate> __nullable weakd;
@property (nonatomic,weak) TGModernGrowingTextView  * _Nullable weakTextView;
@property (nonatomic,strong) NSColor* _Nonnull selectedTextColor;


@end

@interface TGModernGrowingTextView : NSView<NSServicesMenuRequestor>

-(instancetype)initWithFrame:(NSRect)frameRect unscrollable:(BOOL)unscrollable;

@property (nonatomic,assign) BOOL animates;

@property (nonatomic,assign) int min_height;
@property (nonatomic,assign) int max_height;

@property (nonatomic,assign) BOOL isSingleLine;
@property (nonatomic,assign) BOOL isWhitespaceDisabled;

@property (nonatomic,strong) NSColor* _Nonnull cursorColor;
@property (nonatomic,strong) NSColor* _Nonnull textColor;
@property (nonatomic,strong) NSColor* _Nonnull selectedTextColor;

@property (nonatomic,strong) NSColor* _Nonnull linkColor;
@property (nonatomic,strong) NSFont* _Nonnull textFont;
@property (nonatomic,strong,readonly) TGGrowingTextView* _Nonnull inputView;
@property (nonatomic,strong,readonly) NSScrollView* _Nonnull scroll;


@property (nonatomic,strong, nullable) NSAttributedString *placeholderAttributedString;

-(void)setPlaceholderAttributedString:(NSAttributedString * __nonnull)placeholderAttributedString update:(BOOL)update;

@property (nonatomic,weak) id <TGModernGrowingDelegate> __nullable delegate;

-(int)height;


-(void)update:(BOOL)notify;

-(NSAttributedString * __nonnull)attributedString;
-(void)setAttributedString:(NSAttributedString * __nonnull)attributedString animated:(BOOL)animated;
-(NSString *_Nonnull)string;
-(void)setString:(NSString * __nonnull)string;
-(void)setString:(NSString * __nonnull)string animated:(BOOL)animated;
-(NSRange)selectedRange;
-(void)appendText:(id __nonnull)aString;
-(void)insertText:(id __nonnull)aString replacementRange:(NSRange)replacementRange;
-(void)addInputTextTag:(TGInputTextTag * __nonnull)tag range:(NSRange)range;
-(void)scrollToCursor;
-(void)replaceMention:(NSString * __nonnull)mention username:(bool)username userId:(int32_t)userId;

-(void)paste:(id __nonnull)sender;

-(void)setSelectedRange:(NSRange)range;

-(Class __nonnull)_textViewClass;
-(int)_startXPlaceholder;
-(BOOL)_needShowPlaceholder;

-(void)codeWord;
-(void)italicWord;
-(void)boldWord;
-(void)strikethroughWord;
-(void)makeQuote;
-(void)underlineWord;
-(void)spoilerWord;
-(void)removeAllAttributes;
-(void)addLink:(NSString *_Nullable)link;
-(void)addLink:(NSString *_Nullable)link range: (NSRange)range;
-(void)addLink:(NSString *_Nullable)link text: (NSString * __nonnull)text range: (NSRange)range;

- (void)textDidChange:( NSNotification * _Nullable )notification;

- (void)addSimpleItem:(SimpleUndoItem *)item;

-(void)setBackgroundColor:(NSColor * __nonnull)color;
-(NSRect)highlightRectForRange:(NSRange)aRange whole: (BOOL)whole;
-(void)installGetAttachView:(NSView* _Nullable (^_Nonnull)(TGTextAttachment * _Nonnull, NSSize size))getAttachView;

@end
