//
//  TGModernGrowingTextView.m
//  Telegram
//
//  Created by keepcoder on 12/07/16.
//  Copyright © 2016 keepcoder. All rights reserved.
//

#import "TGModernGrowingTextView.h"
#import <QuartzCore/QuartzCore.h>
#import "DateUtils.h"

@interface MarkdownUndoItem : NSObject
    @property (nonatomic, strong) NSAttributedString *was;
    @property (nonatomic, strong) NSAttributedString *be;
    @property (nonatomic, assign) NSRange inRange;
    -(id)initWithAttributedString:(NSAttributedString *)was be: (NSAttributedString *)be inRange:(NSRange)inRange;
@end

@implementation MarkdownUndoItem
    -(id)initWithAttributedString:(NSAttributedString *)was be: (NSAttributedString *)be inRange:(NSRange)inRange {
        if (self = [super init]) {
            self.was = was;
            self.be = be;
            self.inRange = inRange;
        }
        return self;
    }
@end

static NSString* (^localizationFunc)(NSString *key);

void setInputLocalizationFunc(NSString* (^localizationF)(NSString *key)) {
    localizationFunc = localizationF;
}

NSString * NSLocalized(NSString * key, NSString *comment) {
    if (localizationFunc != nil) {
        return localizationFunc(key);
    } else {
        return NSLocalizedString(key, comment);
    }
}

static BOOL textViewEnableTouchBar = true;

void setTextViewEnableTouchBar(BOOL enableTouchBar) {
    textViewEnableTouchBar = enableTouchBar;
}

@interface GrowingScrollView : NSScrollView

@end

@implementation GrowingScrollView

//-(void)scrollWheel:(NSEvent *)event {
//    if ([self documentView].frame.size.height > self.frame.size.height) {
//        [super scrollWheel:event];
//    } else {
//        [[self superview].enclosingScrollView scrollWheel:event];
//    }
//}

@end

@interface NSTextView ()
-(void)_shareServiceSelected:(id)sender;
@end

@interface TGModernGrowingTextView ()
@property (nonatomic, assign) NSRange _selectedRange;

- (void)refreshAttributes;
@end

NSString *const TGCustomLinkAttributeName = @"TGCustomLinkAttributeName";


@interface TGGrowingTextView ()
    @property (nonatomic, strong) NSUndoManager *undo;
    @property (nonatomic, strong) NSMutableArray<MarkdownUndoItem *> *markdownItems;
@end

@implementation TGGrowingTextView

-(instancetype)initWithFrame:(NSRect)frameRect {
    if(self = [super initWithFrame:frameRect]) {
        self.markdownItems = [NSMutableArray array];
    }
    return self;
}

-(NSPoint)textContainerOrigin {
    
    if(NSHeight(self.frame) <= 34) {
        NSRect newRect = [self.layoutManager usedRectForTextContainer:self.textContainer];
        int yOffset = 1;
        return NSMakePoint(0, roundf( (NSHeight(self.frame) - NSHeight(newRect)  )/ 2 -yOffset  ));
    }
    
    return [super textContainerOrigin];
    
}

-(void)drawRect:(NSRect)dirtyRect {
    
    
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext]
                                          graphicsPort];
    
    BOOL isRetina = self.window.backingScaleFactor == 2.0;
    
    CGContextSetAllowsAntialiasing(context, true);
    CGContextSetShouldSmoothFonts(context, !isRetina);
    CGContextSetAllowsFontSmoothing(context,!isRetina);
    
    [super drawRect:dirtyRect];

}

-(void)paste:(id)sender {
    if (![self.weakd textViewDidPaste:[NSPasteboard generalPasteboard]]) {
        [super paste:sender];
    }
}

-(BOOL)becomeFirstResponder {
    return [super becomeFirstResponder];
}

-(void)changeLayoutOrientation:(id)sender {
    
}

-(NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu = [super menuForEvent:event];
    
    NSMutableArray *removeItems = [[NSMutableArray alloc] init];
    
    [menu.itemArray enumerateObjectsUsingBlock:^(NSMenuItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull s) {
        
        if (item.action == @selector(submenuAction:)) {
            [item.submenu.itemArray enumerateObjectsUsingBlock:^(NSMenuItem * _Nonnull subItem, NSUInteger idx, BOOL * _Nonnull stop) {
                if (subItem.action == @selector(_shareServiceSelected:) || subItem.action == @selector(orderFrontFontPanel:)  || subItem.action == @selector(orderFrontSubstitutionsPanel:) || subItem.action == @selector(orderFrontSubstitutionsPanel:) || subItem.action == @selector(startSpeaking:) || subItem.action == @selector(changeLayoutOrientation:) ) {
                    [removeItems addObject:item];
                    *stop = YES;
                } else if (subItem.action == @selector(capitalizeWord:)) {
                    if ([_weakd respondsToSelector:@selector(canTransformInputText)]) {
                        if (self.selectedRange.length > 0) {
                            if ([_weakd canTransformInputText]) {
                                [self.transformItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                    [item.submenu insertItem:obj atIndex:0];
                                }];
                            }
                        } else {
                            [removeItems addObject:item];
                        }
                    }
                }
            }];
        }
    }];
    
    [removeItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [menu removeItem:obj];
    }];
    
    return menu;
}

-(NSArray *)transformItems {
    
    NSMenuItem *bold = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Bold", nil) action:@selector(boldWord:) keyEquivalent:@"b"];
    [bold setKeyEquivalentModifierMask: NSCommandKeyMask];
    
    NSMenuItem *italic = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Italic", nil) action:@selector(italicWord:) keyEquivalent:@"i"];
    [italic setKeyEquivalentModifierMask: NSCommandKeyMask];
    
    
    NSMenuItem *code = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Code", nil) action:@selector(codeWord:) keyEquivalent:@"k"];
    [code setKeyEquivalentModifierMask: NSShiftKeyMask | NSCommandKeyMask];
    
    NSMenuItem *url = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.URL", nil) action:@selector(makeUrl:) keyEquivalent:@"u"];
    [url setKeyEquivalentModifierMask: NSCommandKeyMask];
    
    return @[code, italic, bold, url];
}


-(NSTouchBar *)makeTouchBar {
    return textViewEnableTouchBar ?  [super makeTouchBar] : nil;
}


-(void)boldWord:(id)sender {
     [self changeFontMarkdown:[NSFont boldSystemFontOfSize:self.font.pointSize]];

   // [self.textStorage addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:self.font.pointSize] range:self.selectedRange];
   // [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
}

-(void)makeUrl:(id)sender {
    [self.weakd makeUrlOfRange:self.selectedRange];
}

-(void)addLink:(NSString *)link {
    [self.textStorage addAttribute:NSLinkAttributeName value: link range:self.selectedRange];
}

-(void)italicWord:(id)sender {
    [self changeFontMarkdown:[[NSFontManager sharedFontManager] convertFont:[NSFont systemFontOfSize:self.font.pointSize] toHaveTrait:NSFontItalicTrait]];
    
//    [self.textStorage addAttribute:NSFontAttributeName value:[[NSFontManager sharedFontManager] convertFont:[NSFont systemFontOfSize:13] toHaveTrait:NSFontItalicTrait] range:self.selectedRange];
//    [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
    
}

-(void)codeWord:(id)sender {
    [self changeFontMarkdown:[NSFont fontWithName:@"Menlo-Regular" size:self.font.pointSize]];
//    [self.textStorage addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Menlo-Regular" size:self.font.pointSize] range:self.selectedRange];
//    [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
}

-(void)changeFontMarkdown:(NSFont *)font  {
    
    if(self.selectedRange.length == 0) {
        return;
    }
    
    
    NSAttributedString *was = [self.attributedString attributedSubstringFromRange:self.selectedRange];

    NSRange effectiveRange;
    NSFont *effectiveFont = [self.textStorage attribute:NSFontAttributeName atIndex:self.selectedRange.location effectiveRange:&effectiveRange];
    
    
    NSFontDescriptor *descriptor = font.fontDescriptor;
    NSFontSymbolicTraits symTraits = [descriptor symbolicTraits];
    BOOL isBold = (symTraits & NSFontBoldTrait) > 0;
    BOOL isItalic = (symTraits & NSFontItalicTrait) > 0;
    BOOL isMonospace = [font.fontName isEqualToString:@"Menlo-Regular"];
    
    descriptor = effectiveFont.fontDescriptor;
    symTraits = [descriptor symbolicTraits];
    BOOL isEffectiveBold = (symTraits & NSFontBoldTrait) > 0;
    BOOL isEffectiveItalic = (symTraits & NSFontItalicTrait) > 0;
    BOOL isEffectiveMonospace = [effectiveFont.fontName isEqualToString:@"Menlo-Regular"];
    
    
    dispatch_block_t block = ^{
        if (self.selectedRange.location >= effectiveRange.location && self.selectedRange.location + self.selectedRange.length <= effectiveRange.location + effectiveRange.length) {
            [self.textStorage addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13] range:self.selectedRange];
        } else if (self.selectedRange.location >= effectiveRange.location) {
            [self.textStorage addAttribute:NSFontAttributeName value:font range:self.selectedRange];
        } else {
            [self.textStorage addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13] range:self.selectedRange];
        }
    };
    
    if (isBold) {
        if (isEffectiveBold) {
            block();
        } else {
            [self.textStorage addAttribute:NSFontAttributeName value:font range:self.selectedRange];
        }
    } else if (isItalic) {
        if (isEffectiveItalic) {
            block();
        } else {
            [self.textStorage addAttribute:NSFontAttributeName value:font range:self.selectedRange];
        }
    } else if (isMonospace) {
        if (isEffectiveMonospace) {
            block();
        } else {
            [self.textStorage addAttribute:NSFontAttributeName value:font range:self.selectedRange];
        }
    }
    
    NSAttributedString *be = [self.attributedString attributedSubstringFromRange:self.selectedRange];
    
 
    
    [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
    
    MarkdownUndoItem *item = [[MarkdownUndoItem alloc] initWithAttributedString:was be:be inRange:self.selectedRange];
    [self addItem:item];
    
}

    
- (void)addItem:(MarkdownUndoItem *)item {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(removeItem:) object:item];
    if (![[self undoManager] isUndoing]) {
        [[self undoManager] setActionName:NSLocalizedString(@"actions.add-item", @"Add Item")];
    }
    [[self textStorage] replaceCharactersInRange:item.inRange withAttributedString:item.be];
    [self.markdownItems addObject:item];
    [self.weakd textViewTextDidChangeSelectedRange:self.selectedRange];
}
    
- (void)removeItem:(MarkdownUndoItem *)item {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(addItem:) object:item];
    if (![[self undoManager] isUndoing]) {
        [[self undoManager] setActionName:NSLocalizedString(@"actions.remove-item", @"Remove Item")];
    }
    if ([self.markdownItems indexOfObject:item] != NSNotFound) {
        [[self textStorage] replaceCharactersInRange:item.inRange withAttributedString:item.was];
        [self.markdownItems removeObject:item];
        [self.weakd textViewTextDidChangeSelectedRange:self.selectedRange];
    }
}


-(BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if(menuItem.action == @selector(changeLayoutOrientation:)) {
        return NO;
    }
    
    
    return [super validateMenuItem:menuItem];
}


- (void)setContinuousSpellCheckingEnabled:(BOOL)flag
{
    [[NSUserDefaults standardUserDefaults] setBool: flag forKey:[NSString stringWithFormat:@"ContinuousSpellCheckingEnabled%@",NSStringFromClass([self class])]];
    [super setContinuousSpellCheckingEnabled: flag];
}

-(BOOL)isContinuousSpellCheckingEnabled {
    return  [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"ContinuousSpellCheckingEnabled%@",NSStringFromClass([self class])]];
}

-(void)setGrammarCheckingEnabled:(BOOL)flag {
    
    [[NSUserDefaults standardUserDefaults] setBool: flag forKey:[NSString stringWithFormat:@"GrammarCheckingEnabled%@",NSStringFromClass([self class])]];
    [super setGrammarCheckingEnabled: flag];
}

-(BOOL)isGrammarCheckingEnabled {
    return  [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"GrammarCheckingEnabled%@",NSStringFromClass([self class])]];
}


-(void)setAutomaticSpellingCorrectionEnabled:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool: flag forKey:[NSString stringWithFormat:@"AutomaticSpellingCorrectionEnabled%@",NSStringFromClass([self class])]];
    [super setAutomaticSpellingCorrectionEnabled: flag];
}

-(BOOL)isAutomaticSpellingCorrectionEnabled {
    return  [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"AutomaticSpellingCorrectionEnabled%@",NSStringFromClass([self class])]];
}



-(void)setAutomaticQuoteSubstitutionEnabled:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool: flag forKey:[NSString stringWithFormat:@"AutomaticQuoteSubstitutionEnabled%@",NSStringFromClass([self class])]];
    [super setAutomaticSpellingCorrectionEnabled: flag];
}

-(BOOL)isAutomaticQuoteSubstitutionEnabled {
    return  [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"AutomaticQuoteSubstitutionEnabled%@",NSStringFromClass([self class])]];
}


-(void)setAutomaticLinkDetectionEnabled:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool: flag forKey:[NSString stringWithFormat:@"AutomaticLinkDetectionEnabled%@",NSStringFromClass([self class])]];
    [super setAutomaticSpellingCorrectionEnabled: flag];
}

-(BOOL)isAutomaticLinkDetectionEnabled {
    return  [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"AutomaticLinkDetectionEnabled%@",NSStringFromClass([self class])]];
}


-(void)setAutomaticDataDetectionEnabled:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool: flag forKey:[NSString stringWithFormat:@"AutomaticDataDetectionEnabled%@",NSStringFromClass([self class])]];
    [super setAutomaticSpellingCorrectionEnabled: flag];
}

-(BOOL)isAutomaticDataDetectionEnabled {
    return  [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"AutomaticDataDetectionEnabled%@",NSStringFromClass([self class])]];
}



-(void)setAutomaticDashSubstitutionEnabled:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool: flag forKey:[NSString stringWithFormat:@"AutomaticDashSubstitutionEnabled%@",NSStringFromClass([self class])]];
    [super setAutomaticSpellingCorrectionEnabled: flag];
}

-(BOOL)isAutomaticDashSubstitutionEnabled {
    return  [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"AutomaticDashSubstitutionEnabled%@",NSStringFromClass([self class])]];
}



-(NSUInteger)numberOfLines {
    NSString *s = [self string];
    
    NSUInteger numberOfLines, index, stringLength = [s length];
    
    for (index = 0, numberOfLines = 0; index < stringLength;
         numberOfLines++) {
        index = NSMaxRange([s lineRangeForRange:NSMakeRange(index, 0)]);
    }
    return numberOfLines;
}

BOOL isEnterEvent(NSEvent *theEvent) {
    BOOL isEnter = (theEvent.keyCode == 0x24 || theEvent.keyCode ==  0x4C); // VK_RETURN
    
    return isEnter;
}



- (void) keyDown:(NSEvent *)theEvent {
    
    if(_weakd.textViewIsTypingEnabled) {
        
        if(isEnterEvent(theEvent) && !(self.hasMarkedText)) {
            
            BOOL result = [_weakd textViewEnterPressed:theEvent];
            
            if(!result) {
                [self insertNewline:self];
            }
            return;
        }   else if(theEvent.keyCode == 53 && [_weakd respondsToSelector:@selector(textViewNeedClose:)]) {
            [_weakd textViewNeedClose:self];
            return;
        }
        
        
        [super keyDown:theEvent];
    } else if(_weakd == nil) {
        [super keyDown:theEvent];
    }
    
}

-(void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
}



-(BOOL)resignFirstResponder {
   return [super resignFirstResponder];
}

-(void)setString:(NSString *)string {
    [super setString:string];
}


@end

@interface TGTextFieldPlaceholder : NSTextField

@end

@implementation TGTextFieldPlaceholder

-(void)drawRect:(NSRect)dirtyRect {
    
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext]
                                          graphicsPort];
    
    BOOL isRetina = self.window.backingScaleFactor == 2.0;
    
    if (isRetina) {
        CGContextSetAllowsAntialiasing(context, true);
        CGContextSetShouldSmoothFonts(context, !isRetina);
        CGContextSetAllowsFontSmoothing(context,!isRetina);
    }
    [super drawRect:dirtyRect];
    
}

@end


@interface TGModernGrowingTextView () <NSTextViewDelegate,CAAnimationDelegate> {
    int _last_height;
}
@property (nonatomic,strong) TGGrowingTextView *textView;
@property (nonatomic,strong) GrowingScrollView *scrollView;
@property (nonatomic,strong) TGTextFieldPlaceholder *placeholder;
@property (nonatomic,assign) BOOL notify_next;
@property (nonatomic, strong) NSUndoManager *_undo;
@end


@implementation TGModernGrowingTextView




-(instancetype)initWithFrame:(NSRect)frameRect {
    if(self = [super initWithFrame:frameRect]) {
        
        _min_height = 34;
        _max_height = 200;
        _animates = YES;
        _cursorColor = [NSColor blackColor];

        _textView = [[[self _textViewClass] alloc] initWithFrame:self.bounds];
        [_textView setRichText:NO];
        [_textView setImportsGraphics:NO];
        _textView.backgroundColor = [NSColor clearColor];
        _textView.insertionPointColor = _cursorColor;
        self.scrollView.backgroundColor = [NSColor clearColor];
        [_textView setAllowsUndo:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionDidChanged:) name:NSTextViewDidChangeSelectionNotification object:_textView];
        
        self._undo = [[NSUndoManager alloc] init];
        self.textView.undo = self._undo;
        self.autoresizesSubviews = YES;
        _textView.delegate = self;
        
        [_textView setDrawsBackground:YES];
        

        
        self.scrollView = [[GrowingScrollView alloc] initWithFrame:self.bounds];
        [[self.scrollView verticalScroller] setControlSize:NSSmallControlSize];
        self.scrollView.documentView = _textView;
        [self.scrollView setDrawsBackground:NO];
        [self.scrollView setFrame:NSMakeRect(0, 0, NSWidth(self.frame), NSHeight(self.frame))];
        [self addSubview:self.scrollView];
        
        
        self.wantsLayer = _textView.wantsLayer = _scrollView.wantsLayer = YES;

        
        _placeholder = [[TGTextFieldPlaceholder alloc] init];
        _placeholder.wantsLayer = YES;
        [_placeholder setBordered:NO];
        [_placeholder setDrawsBackground:NO];
        [_placeholder setSelectable:NO];
        [_placeholder setEditable:NO];
        [[_placeholder cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [_placeholder setEnabled:NO];
        
        [self addSubview:_placeholder];
                
        
    }
    
    return self;
}

-(NSUndoManager *)undoManagerForTextView:(NSTextView *)view {
    return self._undo;
}

-(void)setCursorColor:(NSColor *)cursorColor {
    _cursorColor = cursorColor;
    _textView.insertionPointColor = _cursorColor;
}

-(void)setTextColor:(NSColor *)textColor {
    _textColor = textColor;
    _textView.insertionPointColor = _textColor;
    _textView.textColor = _textColor;
    [self textDidChange:nil];
}

-(void)setTextFont:(NSFont *)textFont {
    _textFont = textFont;
    _textView.font = textFont;
}

-(void)selectionDidChanged:(NSNotification *)notification {
    if (!_notify_next) {
        _notify_next = YES;
        return;
    }
    

    if ((self._selectedRange.location != self.textView.selectedRange.location) || (self._selectedRange.length != self.textView.selectedRange.length)) {
        [self.delegate textViewTextDidChangeSelectedRange:self.textView.selectedRange];
        self._selectedRange = self.textView.selectedRange;
    }
        
    NSRect newRect = [_textView.layoutManager usedRectForTextContainer:_textView.textContainer];
    
    NSSize size = newRect.size;
    size.width = NSWidth(self.frame);
    NSSize newSize = NSMakeSize(size.width, size.height);
    newSize.height+= 8;
    newSize.height = MIN(MAX(newSize.height,_min_height),_max_height);
    
    [self updatePlaceholder:true newSize:newSize];
}

-(void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];
    if(self.window.firstResponder != _textView) {
        [self.window makeFirstResponder:_textView];
    }
    [self update:NO];
}

-(BOOL)becomeFirstResponder {
   // if(self.window.firstResponder != _textView) {
        [self.window makeFirstResponder:_textView];
   // }
    return YES;
}

-(BOOL)resignFirstResponder {
    return [_textView resignFirstResponder];
}

-(int)height {
    return _last_height;
}

-(void)setDelegate:(id<TGModernGrowingDelegate>)delegate {
    _delegate = _textView.weakd = delegate;
}


-(void)update:(BOOL)notify {
    [self textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:notify ? _textView : nil]];
}


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
}

-(BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if ((commandSelector == @selector(deleteBackward:) || commandSelector == @selector(deleteForward:)) && _defaultText.length > 0) {
        if ([textView.string isEqualToString:_defaultText]) {
            return true;
        }
    }
    return false;
}

-(BOOL)textView:(NSTextView *)textView shouldChangeTextInRanges:(NSArray<NSValue *> *)affectedRanges replacementStrings:(NSArray<NSString *> *)replacementStrings {
    if (_defaultText.length > 0) {
        __block BOOL cancel = true;
        [affectedRanges enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSRange range = obj.rangeValue;
            if (range.location < _defaultText.length) {
                cancel = false;
                *stop = YES;
            }
            if (self.isWhitespaceDisabled && range.length == 0 && [replacementStrings[idx] isEqualToString:@" "]) {
                cancel = false;
                *stop = YES;
            }
        }];
        if (cancel) {
            [self setSelectedRange:NSMakeRange(textView.string.length, 0)];
        }
        
        return cancel;
    }
    return true;
}




- (void)textDidChange:(NSNotification *)notification {
    
    
    int limit = self.delegate == nil ? INT32_MAX : [self.delegate maxCharactersLimit: self];
    
    if (self.string != nil && self.string.length > 0 && self.string.length - _defaultText.length > limit) {
        NSString *sub = [self.string substringWithRange:NSMakeRange(_defaultText.length, limit)];
        [self setString:sub animated: notification != nil];
        if ([self.delegate respondsToSelector:@selector(textViewDidReachedLimit:)])
            [self.delegate textViewDidReachedLimit: self];
        return;
    }
    
    if (self.isWhitespaceDisabled) {
        NSString *n = [[self string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![n isEqualToString:[self string]]) {
            [self setString:n];
            return;
        }
    }
    if (self.isSingleLine) {
        NSString *n = [[self string] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        if (![n isEqualToString:[self string]]) {
            [self setString:n];
            return;
        }
    }
    
    self.scrollView.verticalScrollElasticity = NSHeight(_scrollView.contentView.documentRect) <= NSHeight(_scrollView.frame) ? NSScrollElasticityNone : NSScrollElasticityAllowed;
    
    [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
    NSRect newRect = [_textView.layoutManager usedRectForTextContainer:_textView.textContainer];
    
    NSSize size = newRect.size;
    size.width = NSWidth(self.frame);
    

    NSSize newSize = NSMakeSize(size.width, size.height);

    
    newSize.height+= 2;
    
    
    newSize.height = MIN(MAX(newSize.height,_min_height),_max_height);
    
    BOOL animated = self.animates;
    
    
    if(_last_height != newSize.height) {
        
        dispatch_block_t future = ^ {
            
            _last_height = newSize.height;
            if (notification.object != nil) {
                [_delegate textViewHeightChanged:(CGFloat)newSize.height animated:animated];
            }
        };
        
        [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
        
        newSize.width = [_delegate textViewSize: self].width;
        
        NSSize layoutSize = NSMakeSize(roundf(newSize.width), roundf(newSize.height));
        
        
        if(animated) {
            
            [CATransaction begin];
            
            float presentHeight = NSHeight(self.frame);
            
            CALayer *presentLayer = (CALayer *)[self.layer presentationLayer];
            
            if(presentLayer && [self.layer animationForKey:@"bounds"]) {
                presentHeight = [[presentLayer valueForKeyPath:@"bounds.size.height"] floatValue];
            }
            
            CABasicAnimation *sAnim = [CABasicAnimation animationWithKeyPath:@"bounds.size.height"];
            sAnim.duration = 0.2;
            sAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            sAnim.removedOnCompletion = YES;
            
            sAnim.fromValue = @(presentHeight);
            sAnim.toValue = @(layoutSize.height);
            
            [self.layer removeAnimationForKey:@"bounds"];
            [self.layer addAnimation:sAnim forKey:@"bounds"];
            
            [self.layer setFrame:NSMakeRect(NSMinX(self.frame), NSMinY(self.frame), NSWidth(self.frame), layoutSize.height)];
            
            
            
            presentHeight = NSHeight(_scrollView.frame);
            presentLayer = (CALayer *)[_scrollView.layer presentationLayer];
            
            if(presentLayer && [_scrollView.layer animationForKey:@"bounds"]) {
                presentHeight = [[presentLayer valueForKeyPath:@"bounds.size.height"] floatValue];
            }
            
            
            sAnim.fromValue = @(presentHeight);
            sAnim.toValue = @(layoutSize.height);
            
            [_scrollView.layer removeAnimationForKey:@"bounds"];
            [_scrollView.layer addAnimation:sAnim forKey:@"bounds"];
            
            
            [self setFrame:NSMakeRect(NSMinX(self.frame), NSMinY(self.frame), layoutSize.width, layoutSize.height)];
            [_scrollView setFrameSize:layoutSize];
            

            
        
            future();
            
            [CATransaction commit];

            
        } else {
            [self setFrameSize:layoutSize];
            future();
        }
        
    }
    
    
 //   if(self._needShowPlaceholder) {
    
    [self updatePlaceholder: animated newSize: newSize];
    
    
    [self setNeedsDisplay:YES];
    
    if (_textView.selectedRange.location != NSNotFound) {
        [_textView setSelectedRange:_textView.selectedRange];
    }
    
    [self setNeedsDisplay:YES];
    
    if(notification.object) {
        NSString *text = self.string;
        if (_defaultText.length > 0) {
            NSRange range = [text rangeOfString:_defaultText];
            if (range.location != NSNotFound) {
                text = [text substringFromIndex:range.location + range.length];
            } else if ([_defaultText containsString:text]) {
                text = @"";
            }
        }
        [self.delegate textViewTextDidChange:text];
        
    }
    
    [self refreshAttributes];
    
}

- (NSRect) highlightRectForRange:(NSRange)aRange
{
    NSRange r = aRange;
    NSRange startLineRange = [[self string] lineRangeForRange:NSMakeRange(r.location, 0)];
    NSInteger er = NSMaxRange(r)-1;
    NSString *text = [self string];
    
    if (er >= [text length]) {
        return NSZeroRect;
    }
    if (er < r.location) {
        er = r.location;
    }
    
    
    NSRange gr = [[self.textView layoutManager] glyphRangeForCharacterRange:aRange
                                              actualCharacterRange:NULL];
    NSRect br = [[self.textView layoutManager] boundingRectForGlyphRange:gr inTextContainer:[self.textView textContainer]];
    NSRect b = [self bounds];
    CGFloat h = br.size.height;
    CGFloat w = b.size.width;
    CGFloat y = br.origin.y;
    NSPoint containerOrigin = [self.textView textContainerOrigin];
    NSRect aRect = NSMakeRect(0, y, w, h);
    // Convert from view coordinates to container coordinates
    aRect = NSOffsetRect(aRect, containerOrigin.x, containerOrigin.y);
    return aRect;
}

-(void)scrollToCursor {
    NSRect lineRect = [self highlightRectForRange:self.selectedRange];
    
    [self.scrollView.contentView scrollToPoint:lineRect.origin];
}

-(void)updatePlaceholder:(BOOL)animated newSize:(NSSize)newSize {
    if(_placeholderAttributedString) {
        
        if(animated && ((self.string.length == 0 && _placeholder.layer.opacity < 1.0f) || (self.string.length > 0 && _placeholder.layer.opacity > 0.0f))) {
            float presentX = self._needShowPlaceholder ? self._endXPlaceholder : self._startXPlaceholder;
            float presentOpacity = self._needShowPlaceholder ? 0.0f : 1.0f;
            
            CALayer *presentLayer = (CALayer *)[_placeholder.layer presentationLayer];
            
            if(presentLayer && [_placeholder.layer animationForKey:@"position"]) {
                presentX = [[presentLayer valueForKeyPath:@"frame.origin.x"] floatValue];
            }
            if(presentLayer && [_placeholder.layer animationForKey:@"opacity"]) {
                presentOpacity = [[presentLayer valueForKeyPath:@"opacity"] floatValue];
            }
            [_placeholder setHidden:NO];
            
            CABasicAnimation *oAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
            oAnim.fromValue = @(presentOpacity);
            oAnim.toValue = @(self._needShowPlaceholder ? 1.0f : 0.0f);
            oAnim.duration = 0.2;
            oAnim.removedOnCompletion = YES;
            oAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            
            oAnim.delegate = self;
            
            [_placeholder.layer removeAnimationForKey:@"opacity"];
            [_placeholder.layer addAnimation:oAnim forKey:@"opacity"];
            
            
            CABasicAnimation *pAnim = [CABasicAnimation animationWithKeyPath:@"position"];
            pAnim.removedOnCompletion = YES;
            pAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            pAnim.duration = 0.2;
            pAnim.fromValue = [NSValue valueWithPoint:NSMakePoint(presentX, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0)))];
            pAnim.toValue =  [NSValue valueWithPoint:self._needShowPlaceholder ? NSMakePoint(self._startXPlaceholder, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0))) : NSMakePoint(self._endXPlaceholder, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0)))];
            
            
            [_placeholder.layer removeAnimationForKey:@"position"];
            [_placeholder.layer addAnimation:pAnim forKey:@"position"]; 
            
        } else {
            if (_placeholder.layer.animationKeys.count == 0) {
                [_placeholder setHidden:!self._needShowPlaceholder];
            }
        }
        
        
        [_placeholder setFrameOrigin:self._needShowPlaceholder ? NSMakePoint(self._startXPlaceholder, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0))) : NSMakePoint(NSMinX(_placeholder.frame) + 30, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0)))];
        
        _placeholder.layer.opacity = self._needShowPlaceholder ? 1.0 : 0.0;
        
        
        [self needsDisplay];
    }
}

-(TGGrowingTextView *)inputView {
    return _textView;
}

-(void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    [_placeholder setHidden:!self._needShowPlaceholder];
}

-(void)setLinkColor:(NSColor *)linkColor {
    _linkColor = linkColor;
}

-(void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_scrollView setFrame:NSMakeRect(0, 0, newSize.width, newSize.height)];
    [_textView setFrame:NSMakeRect(0, 0, NSWidth(_scrollView.frame), NSHeight(_textView.frame))];
    
    
    [_placeholder sizeToFit];
    [_placeholder setFrameSize:NSMakeSize(MIN(NSWidth(_textView.frame) - self._startXPlaceholder - 10,NSWidth(_placeholder.frame)), NSHeight(_placeholder.frame))];
    [_placeholder setFrameOrigin:self._needShowPlaceholder ? NSMakePoint(self._startXPlaceholder, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0))) : NSMakePoint(NSMinX(_placeholder.frame) + 30, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0)))];
}

-(BOOL)_needShowPlaceholder {
    return self.string.length == 0 && _placeholderAttributedString && !_textView.hasMarkedText;
}

-(void)setPlaceholderAttributedString:(NSAttributedString *)placeholderAttributedString update:(BOOL)update {
    
    if([_placeholderAttributedString isEqualToAttributedString:placeholderAttributedString])
        return;
    
    _placeholderAttributedString = placeholderAttributedString;
    [_placeholder setAttributedStringValue:_placeholderAttributedString];
    
    [_placeholder sizeToFit];
    
    [_placeholder setFrameSize:NSMakeSize(MIN(NSWidth(_textView.frame) - self._startXPlaceholder - 10,NSWidth(_placeholder.frame)), NSHeight(_placeholder.frame))];
    [_placeholder setFrameOrigin:self._needShowPlaceholder ? NSMakePoint(self._startXPlaceholder, fabsf(roundf((self.frame.size.height - NSHeight(_placeholder.frame))/2.0))) : NSMakePoint(NSMinX(_placeholder.frame) + 30, fabsf(roundf((self.frame.size.height - NSHeight(_placeholder.frame))/2.0)))];
    BOOL animates = _animates;
    _animates = NO;
    if (self.string.length == 0) {
         [self update:update];
    }
    _animates = animates;

}

-(void)setPlaceholderAttributedString:(NSAttributedString *)placeholderAttributedString {
    [self setPlaceholderAttributedString:placeholderAttributedString update:YES];
}

-(NSParagraphStyle *)defaultParagraphStyle {
    static NSMutableParagraphStyle *para;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        para = [[NSMutableParagraphStyle alloc] init]; 
    });
    
    [para setLineSpacing:0];
    [para setMaximumLineHeight:18];
    
    
    return para;
}


- (void)refreshAttributes {
    
    @try {
        NSAttributedString *string = _textView.attributedString;
        if (string.length == 0) {
            return;
        }
        
        
        
        [_textView.textStorage addAttribute:NSForegroundColorAttributeName value:self.textColor range:NSMakeRange(0, string.length)];
        
        

        __block NSMutableArray<TGInputTextTagAndRange *> *inputTextTags = [[NSMutableArray alloc] init];
        [string enumerateAttribute:TGCustomLinkAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
            if ([value isKindOfClass:[TGInputTextTag class]]) {
                [inputTextTags addObject:[[TGInputTextTagAndRange alloc] initWithTag:value range:range]];
            }
        }];
        
        
        static NSCharacterSet *alphanumericSet = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            alphanumericSet = [NSCharacterSet alphanumericCharacterSet];
        });
        
        NSMutableSet<NSNumber *> *removeTags = [[NSMutableSet alloc] init];
        for (NSInteger i = 0; i < ((NSInteger)inputTextTags.count); i++) {
            TGInputTextTagAndRange *tagAndRange = inputTextTags[i];
            if ([removeTags containsObject:@(tagAndRange.tag.uniqueId)]) {
                [inputTextTags removeObjectAtIndex:i];
                [_textView.textStorage removeAttribute:TGCustomLinkAttributeName range:tagAndRange.range];
                
                i--;
            } else {
                NSInteger j = tagAndRange.range.location;
                while (j < (NSInteger)(tagAndRange.range.location + tagAndRange.range.length)) {
                    unichar c = [string.string characterAtIndex:j];
                    if (c != ' ') {
                        break;
                    }
                    j++;
                }
                
                if (j != (NSInteger)tagAndRange.range.location) {
                    NSRange updatedRange = NSMakeRange(j, tagAndRange.range.location + tagAndRange.range.length - j);
                    [_textView.textStorage removeAttribute:TGCustomLinkAttributeName range:tagAndRange.range];
                    
                    [_textView.textStorage addAttribute:TGCustomLinkAttributeName value:tagAndRange.tag range:updatedRange];
                    
                    inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                    
                    i--;
                } else {
                    NSInteger j = tagAndRange.range.location;
                    while (j >= 0) {
                        
                        unichar c = [string.string characterAtIndex:j];
                        if (![alphanumericSet characterIsMember:c]) {
                            break;
                        }
                        j--;
                    }
                    j++;
                    
                    if (j < ((NSInteger)tagAndRange.range.location)) {
                        NSRange updatedRange = NSMakeRange(j, tagAndRange.range.location + tagAndRange.range.length - j);
                        [_textView.textStorage removeAttribute:TGCustomLinkAttributeName range:tagAndRange.range];
                        
                        [_textView.textStorage addAttribute:TGCustomLinkAttributeName value:tagAndRange.tag range:updatedRange];
                        
                        inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                        
                        i--;
                    } else {
                        TGInputTextTagAndRange *nextTagAndRange = nil;
                        if (i != ((NSInteger)inputTextTags.count) - 1) {
                            nextTagAndRange = inputTextTags[i + 1];
                        }
                        
                        if (nextTagAndRange == nil || nextTagAndRange.tag.uniqueId != tagAndRange.tag.uniqueId) {
                            NSInteger candidateStart = tagAndRange.range.location + tagAndRange.range.length;
                            NSInteger candidateEnd = nextTagAndRange == nil ? string.length : nextTagAndRange.range.location;
                            NSInteger j = candidateStart;
                            while (j < candidateEnd) {
                                unichar c = [string.string characterAtIndex:j];
                                NSCharacterSet *alphanumericSet = [NSCharacterSet alphanumericCharacterSet];
                                if (![alphanumericSet characterIsMember:c]) {
                                    break;
                                }
                                j++;
                            }
                            
                            if (j == candidateStart) {
                                [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                [_textView.textStorage addAttribute:tagAndRange.tag.attribute.name value:tagAndRange.tag.attribute.value range:tagAndRange.range];
                            } else {
                                [_textView.textStorage removeAttribute:TGCustomLinkAttributeName range:tagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                [_textView.textStorage addAttribute:TGCustomLinkAttributeName value:tagAndRange.tag range:updatedRange];
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                
                                i--;
                            }
                        } else {
                            
                            
                            NSInteger candidateStart = tagAndRange.range.location + tagAndRange.range.length;
                            NSInteger candidateEnd = nextTagAndRange.range.location;
                            NSInteger j = candidateStart;
                            while (j < candidateEnd) {
                                unichar c = [string.string characterAtIndex:j];
                                if (![alphanumericSet characterIsMember:c] && c != ' ') {
                                    break;
                                }
                                j++;
                            }
                            
                            if (j == candidateEnd) {
                                [_textView.textStorage removeAttribute:TGCustomLinkAttributeName range:tagAndRange.range];
                                
                                [_textView.textStorage removeAttribute:TGCustomLinkAttributeName range:nextTagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, nextTagAndRange.range.location + nextTagAndRange.range.length - tagAndRange.range.location);
                                
                                [_textView.textStorage addAttribute:TGCustomLinkAttributeName value:tagAndRange.tag range:updatedRange];
                                
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                [inputTextTags removeObjectAtIndex:i + 1];
                                
                                i--;
                            } else if (j != candidateStart) {
                                [_textView.textStorage removeAttribute:TGCustomLinkAttributeName range:tagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                [_textView.textStorage addAttribute:TGCustomLinkAttributeName value:tagAndRange.tag range:updatedRange];
                                
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                
                                i--;
                            } else {
                                [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                [_textView.textStorage addAttribute:tagAndRange.tag.attribute.name value:tagAndRange.tag.attribute.value range:tagAndRange.range];
                            }
                        }
                    }
                }
            }
        }


    } @catch (NSException *exception) {
        
    }
}

-(void)boldWord {
    [self.textView boldWord:nil];
}

-(void)italicWord {
    [self.textView italicWord:nil];
}

-(void)codeWord {
    [self.textView codeWord:nil];
}





-(NSString *)string {
    if (_textView.string == nil) {
        return @"";
    }
    return [_textView.string copy];
}

-(NSAttributedString *)attributedString {
    return _textView.attributedString;
}

-(void)setAttributedString:(NSAttributedString *)attributedString animated:(BOOL)animated {
    
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
    
    [attributedString enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(NSFont *value, NSRange range, BOOL * _Nonnull stop) {
        [attr addAttribute:NSFontAttributeName value:[[NSFontManager sharedFontManager] convertFont:value toSize:_textFont.pointSize] range:range];
    }];
    
    
    [_textView.textStorage setAttributedString:attr];
    BOOL o = self.animates;
    self.animates = animated;
    [self update:animated];
    self.animates = o;
}

-(NSString *)textWithDefault:(NSString *)string {
    NSString *text = _defaultText.length > 0 ? [_defaultText stringByAppendingString:string] : string;
    
    return text;
}

-(void)setString:(NSString *)string {

    if (![string isEqualToString:[self textWithDefault:self.string]]) {
        [self setString:string animated:YES];
    }
}

-(void)setString:(NSString *)string animated:(BOOL)animated {
    [_textView setString:[self textWithDefault:string]];
    BOOL o = self.animates;
    self.animates = animated;
    [self update:animated];
    self.animates = o;
}
-(NSRange)selectedRange {
    return _textView.selectedRange;
}

-(void)insertText:(id)aString replacementRange:(NSRange)replacementRange {
    [_textView insertText:aString replacementRange:replacementRange];
}

-(void)appendText:(id)aString {
    [_textView insertText:aString replacementRange:self.selectedRange];
}

-(void)addInputTextTag:(TGInputTextTag *)tag range:(NSRange)range {
    NSAttributedString *was = [self.textView.textStorage attributedSubstringFromRange:range];
    [_textView.textStorage addAttribute:TGCustomLinkAttributeName value:tag range:range];
    MarkdownUndoItem *item = [[MarkdownUndoItem alloc] initWithAttributedString:was be:[self.textView.textStorage attributedSubstringFromRange:range] inRange:range];
    [self.textView addItem:item];
}

static int64_t nextId = 0;

-(void)addLink:(NSString *)link {
    if (self.selectedRange.length == 0)
        return;
    id tag = [[TGInputTextTag alloc] initWithUniqueId:++nextId attachment:link attribute:[[TGInputTextAttribute alloc] initWithName:NSForegroundColorAttributeName value:_linkColor]];
    [self addInputTextTag:tag range:self.selectedRange];
    [self update:YES];
}


- (void)replaceMention:(NSString *)mention username:(bool)username userId:(int32_t)userId
{
    NSString *replacementText = [mention stringByAppendingString:@" "];
    
    NSMutableAttributedString *text = _textView.attributedString == nil ? [[NSMutableAttributedString alloc] init] : [[NSMutableAttributedString alloc] initWithAttributedString:_textView.attributedString];
    
    NSRange selRange = _textView.selectedRange;
    NSUInteger selStartPos = selRange.location;
    
    NSInteger idx = selStartPos;
    idx--;
    
    NSRange candidateMentionRange = NSMakeRange(NSNotFound, 0);
    
    if (idx >= 0 && idx < (int)text.length)
    {
        for (NSInteger i = idx; i >= 0; i--)
        {
            unichar c = [text.string characterAtIndex:i];
            if (c == '@')
            {
                if (i == idx)
                    candidateMentionRange = NSMakeRange(i + 1, selRange.length);
                else
                    candidateMentionRange = NSMakeRange(i + 1, idx - i);
                break;
            }
            
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'))
                break;
        }
    }
    
    if (candidateMentionRange.location != NSNotFound)
    {
        if (!username) {
            candidateMentionRange.location -= 1;
            candidateMentionRange.length += 1;
            
            [text replaceCharactersInRange:candidateMentionRange withString:replacementText];
            
            nextId++;
            [text addAttributes:@{TGCustomLinkAttributeName: [[TGInputTextTag alloc] initWithUniqueId:nextId attachment:@(userId) attribute:[[TGInputTextAttribute alloc] initWithName:NSForegroundColorAttributeName value:_linkColor]]} range:NSMakeRange(candidateMentionRange.location, replacementText.length - 1)];
        } else {
            [text replaceCharactersInRange:candidateMentionRange withString:replacementText];
        }
        
        [_textView.textStorage setAttributedString:text];
    }
    
    [self update:YES];
}

-(void)paste:(id)sender {
    [_textView paste:sender];
}

-(void)setSelectedRange:(NSRange)range {
    _notify_next = NO;
    if(range.location != NSNotFound)
        [_textView setSelectedRange:range];
}

-(Class)_textViewClass {
    return [TGGrowingTextView class];
}

-(void)dealloc {
    [__undo removeAllActionsWithTarget:_textView];
    [__undo removeAllActions];
}




-(int)_startXPlaceholder {
    return NSMinX(_scrollView.frame) + 4;
}

-(int)_endXPlaceholder {
    return self._startXPlaceholder + 30;
}

@end
