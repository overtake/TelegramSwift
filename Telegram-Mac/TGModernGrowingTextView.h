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
@class TGModernGrowingTextView;

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
- (void) textViewNeedClose:(id __nonnull)textView;
- (BOOL) canTransformInputText;
- (void)textViewDidReachedLimit:(id __nonnull)textView;
- (void)makeUrlOfRange: (NSRange)range;
@end


void setInputLocalizationFunc(NSString* _Nonnull (^ _Nonnull localizationF)(NSString * _Nonnull key));
void setTextViewEnableTouchBar(BOOL enableTouchBar);

@interface TGGrowingTextView : NSTextView
@property (nonatomic,weak) id <TGModernGrowingDelegate> __nullable weakd;
@end

@interface TGModernGrowingTextView : NSView

@property (nonatomic,assign) BOOL animates;

@property (nonatomic,assign) int min_height;
@property (nonatomic,assign) int max_height;

@property (nonatomic,assign) BOOL isSingleLine;
@property (nonatomic,assign) BOOL isWhitespaceDisabled;

@property (nonatomic,strong) NSColor* _Nonnull cursorColor;
@property (nonatomic,strong) NSColor* _Nonnull textColor;
@property (nonatomic,strong) NSColor* _Nonnull linkColor;
@property (nonatomic,strong) NSFont* _Nonnull textFont;
@property (nonatomic,strong) NSString* _Nonnull defaultText;
@property (nonatomic,strong,readonly) TGGrowingTextView* _Nonnull inputView;


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
-(void)addLink:(NSString *_Nonnull)link;
- (void)textDidChange:( NSNotification * _Nullable )notification;
@end
