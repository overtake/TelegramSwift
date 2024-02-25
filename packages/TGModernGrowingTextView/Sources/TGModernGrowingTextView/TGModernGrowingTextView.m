//
//  TGModernGrowingTextView.m
//  Telegram
//
//  Created by keepcoder on 12/07/16.
//  Copyright © 2016 keepcoder. All rights reserved.
//

#import "TGModernGrowingTextView.h"
#import <QuartzCore/QuartzCore.h>

static int64_t nextId = 0;



@interface TGTextFieldPlaceholder : NSTextField
    
    @end

@interface TGModernGrowingTextView ()
@property (nonatomic,strong) TGTextFieldPlaceholder *placeholder;
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


@implementation SimpleUndoItem
-(id)initWithAttributedString:(NSAttributedString *)was be: (NSAttributedString *)be wasRange:(NSRange)wasRange beRange:(NSRange)beRange {
    if (self = [super init]) {
        self.was = was;
        self.be = be;
        self.wasRange = wasRange;
        self.beRange = beRange;
    }
    return self;
}
    
-(void)setWas:(NSAttributedString *)was {
    self->_was = was;
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


@interface GrowingScrollView : NSScrollView
    
@end

@implementation GrowingScrollView
    
    
@end

@interface UnscrollableTextScrollView : NSScrollView
    
@end

@implementation UnscrollableTextScrollView
    
-(void)scrollWheel:(NSEvent *)event {
    [[self superview].enclosingScrollView scrollWheel:event];
}
    
    @end

@interface NSTextView ()
-(void)_shareServiceSelected:(id)sender;
    @end

@interface TGModernGrowingTextView ()
    @property (nonatomic, assign) NSRange _selectedRange;
    
- (void)refreshAttributes;
    @end

NSString *const TGCustomLinkAttributeName = @"TGCustomLinkAttributeName";
NSString *const TGSpoilerAttributeName = @"TGSpoilerAttributeName";
NSString *const TGAnimatedEmojiAttributeName = @"TGAnimatedEmojiAttributeName";
NSString *const TGEmojiHolderAttributeName = @"TGEmojiHolderAttributeName";



@interface TGGrowingTextView ()
@property (nonatomic, strong) NSUndoManager *undo;
@property (nonatomic, strong) NSMutableArray<MarkdownUndoItem *> *markdownItems;
@property (nonatomic, strong) NSTrackingArea *trackingArea;
- (NSRect) highlightRectForRange:(NSRange)aRange whole: (BOOL)whole;
@end


@interface TGModernGrowingTextView ()
-(void)textDidChange:(NSNotification *)notification;
    
@end



@implementation TGGrowingTextView
    
-(instancetype)initWithFrame:(NSRect)frameRect {
    if(self = [super initWithFrame:frameRect]) {
        self.markdownItems = [NSMutableArray array];
        
        NSTrackingArea *trackingArea = [[NSTrackingArea alloc]initWithRect:self.bounds options:NSTrackingCursorUpdate | NSTrackingActiveInActiveApp owner:self userInfo:nil];
        [self addTrackingArea:trackingArea];
        
#ifdef __MAC_10_12_2
        //  self.allowsCharacterPickerTouchBarItem = false;
#endif
    }
    return self;
}
    
    - (void)mouseMoved:(NSEvent *)event
    {
    }
    
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingMouseEnteredAndExited | NSTrackingCursorUpdate) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}
    
-(id)validRequestorForSendType:(NSPasteboardType)sendType returnType:(NSPasteboardType)returnType {
    if (([NSImage.imageTypes containsObject:returnType]) && [self.weakd respondsToSelector:@selector(supportContinuityCamera)] && [self.weakd supportContinuityCamera]) {
        return self;
    } else {
        return nil;
    }
}
    
-(BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard {
    if([pboard canReadItemWithDataConformingToTypes:NSImage.imageTypes]) {
        [self.weakd textViewDidPaste:pboard];
        return YES;
    } else {
        return [super readSelectionFromPasteboard:pboard];
    }
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
    
    
    
    NSRange range = NSMakeRange(0, self.attributedString.length);
    
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    
    
    [self.attributedString enumerateAttribute:TGSpoilerAttributeName inRange:range options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
        if ([value isKindOfClass:[TGInputTextTag class]]) {
            TGInputTextTag *tag = (TGInputTextTag *)value;
            if ([tag.attachment intValue] == inputTagIdSpoiler) {
                [ranges addObject:[NSValue valueWithRange:range]];
            }
        }
    }];
    
    
    for (int i = 0; i < ranges.count; i++) {
        NSRange range = [[ranges objectAtIndex:i] rangeValue];
        for (int j = 0; j < range.length; j++) {
            NSRect rect = [self highlightRectForRange:NSMakeRange(range.location + j, 1) whole:false];
            CGContextClearRect(context, rect);
            CGContextSetFillColorWithColor(context, [[_weakTextView.textColor colorWithAlphaComponent:0.15] CGColor]);
            CGContextFillRect(context, rect);
        }

    }
    
    [super drawRect:dirtyRect];

    
}

- (id)accessibilityFocusedUIElement {
    return nil;
}


- (NSRect) highlightRectForRange:(NSRange)aRange whole: (BOOL)whole
{
    if (aRange.location > self.string.length || self.string.length == 0) {
        return NSZeroRect;
    }
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
    
    
    NSRange gr = [[self layoutManager] glyphRangeForCharacterRange:aRange
                                                       actualCharacterRange:NULL];
    NSRect br = [[self layoutManager] boundingRectForGlyphRange:gr inTextContainer:[self textContainer]];
    NSRect b = [self bounds];
    CGFloat h = br.size.height;
    CGFloat w = 0;
    if (whole) {
        w = b.size.width;
    } else {
        w = br.size.width;
    }
    CGFloat y = br.origin.y;
    NSPoint containerOrigin = [self textContainerOrigin];
    NSRect aRect = NSZeroRect;
    if (whole) {
        aRect = NSMakeRect(0, y, w, h);
    } else {
        aRect = br;
    }
    // Convert from view coordinates to container coordinates
    aRect = NSOffsetRect(aRect, containerOrigin.x, containerOrigin.y);
    return aRect;
}
    
- (id)accessibilityParent {
    return nil;
}
    
-(void)setSelectedRange:(NSRange)selectedRange {
    [super setSelectedRange:selectedRange];
}
-(void)rightMouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    [super rightMouseDown:event];
}
    
-(void)paste:(id)sender {
    if (![self.weakd textViewDidPaste:[NSPasteboard generalPasteboard]]) {
        [super paste:sender];
    }
}
    
-(BOOL)becomeFirstResponder {
    return [super becomeFirstResponder];
}
    
-(BOOL)resignFirstResponder {
    return [super resignFirstResponder];
}
    
-(void)changeLayoutOrientation:(id)sender {
    
}
    
-(NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu = [super menuForEvent:event];
    
    NSMutableArray *removeItems = [[NSMutableArray alloc] init];
    
    __block BOOL addedTransformations = false;

    
    
    
    [menu.itemArray enumerateObjectsUsingBlock:^(NSMenuItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull s) {
        
        if (item.action == @selector(submenuAction:)) {
            [item.submenu.itemArray enumerateObjectsUsingBlock:^(NSMenuItem * _Nonnull subItem, NSUInteger idx, BOOL * _Nonnull stop) {
                
                if (subItem
                    .action == @selector(_shareServiceSelected:) || subItem.action == @selector(orderFrontFontPanel:)  || subItem.action == @selector(orderFrontSubstitutionsPanel:) || subItem.action == @selector(orderFrontSubstitutionsPanel:) || subItem.action == @selector(startSpeaking:) || subItem.action == @selector(changeLayoutOrientation:) ) {
                    [removeItems addObject:item];
                    *stop = YES;
                } else if (subItem.action == @selector(capitalizeWord:)) {
                    addedTransformations = true;
                    if ([_weakd respondsToSelector:@selector(canTransformInputText)]) {
                        if (self.selectedRange.length > 0) {
                            if ([_weakd canTransformInputText]) {
                                [self.transformItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                    [item.submenu insertItem:obj atIndex:0];
                                }];
                                 [item.submenu insertItem:[NSMenuItem separatorItem] atIndex: self.transformItems.count];
                                //     [item.submenu insertItem:[[NSMenuItem alloc] initWithTitle:@"Remove All Transformations" action:nil keyEquivalent:nil] atIndex:0];
                            }
                        } else {
                            [removeItems addObject:item];
                        }
                    }
                }
            }];
        }
    }];
    
    if (!addedTransformations) {
        if ([_weakd respondsToSelector:@selector(canTransformInputText)]) {
            if (self.selectedRange.length > 0) {
                if ([_weakd canTransformInputText]) {
                    NSMenuItem *sep = [NSMenuItem separatorItem];
                    [menu addItem: sep];
                    
                    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"Text.View.Transformations", nil) action:nil keyEquivalent:@""];
                    
                    item.submenu = [[NSMenu alloc] init];
                    
                    [self.transformItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        [item.submenu insertItem:obj atIndex:0];
                    }];
                    [menu addItem:item];
                }
            }
        }
    }
    
    [removeItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [menu removeItem:obj];
    }];
    
    [self.window makeFirstResponder:self];
    return menu;
}
    
-(NSArray *)transformItems {
    
    NSMenuItem *bold = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Bold", nil) action:@selector(boldWord:) keyEquivalent:@"b"];
    [bold setKeyEquivalentModifierMask: NSEventModifierFlagCommand];
    
    NSMenuItem *italic = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Italic", nil) action:@selector(italicWord:) keyEquivalent:@"i"];
    [italic setKeyEquivalentModifierMask: NSEventModifierFlagCommand];
    
    
    NSMenuItem *code = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Code", nil) action:@selector(codeWord:) keyEquivalent:@"k"];
    [code setKeyEquivalentModifierMask: NSEventModifierFlagShift | NSEventModifierFlagCommand];
    
    NSMenuItem *url = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.URL1", nil) action:@selector(makeUrl:) keyEquivalent:@"u"];
    [url setKeyEquivalentModifierMask: NSEventModifierFlagCommand];
    
    NSMenuItem *strikethrough = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Strikethrough", nil) action:@selector(makeStrikethrough:) keyEquivalent:@"x"];
    [strikethrough setKeyEquivalentModifierMask: NSEventModifierFlagShift | NSEventModifierFlagCommand];

    NSMenuItem *underline = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Underline", nil) action:@selector(makeUnderline:) keyEquivalent:@"u"];
    [underline setKeyEquivalentModifierMask: NSEventModifierFlagShift | NSEventModifierFlagCommand];

    
    NSMenuItem *spoiler = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.Spoiler", nil) action:@selector(makeSpoiler:) keyEquivalent:@"p"];
    [spoiler setKeyEquivalentModifierMask: NSEventModifierFlagShift | NSEventModifierFlagCommand];

    
    
    NSMenuItem *removeAll = [[NSMenuItem alloc] initWithTitle:NSLocalized(@"TextView.Transform.RemoveAll", nil) action:@selector(removeAll:) keyEquivalent:@""];
    
    
    return @[removeAll, [NSMenuItem separatorItem], strikethrough, underline, spoiler, code, italic, bold, url];
}
    
-(void)removeAll:(id)sender {
    NSRange selectedRange = self.selectedRange;
    NSMutableAttributedString *attr = [self.attributedString mutableCopy];
    [attr setAttributes:nil range:selectedRange];
    [attr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:self.font.pointSize] range: selectedRange];

    
    [self.textStorage setAttributedString:attr];
    [self setSelectedRange:NSMakeRange(selectedRange.location + selectedRange.length, 0)];
    //    [attr enumerateAttributesInRange:selectedRange options:nil usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
    //
    //    }];
}
    
-(void)boldWord:(id)sender {
    if(self.selectedRange.length == 0) {
        return;
    }
    
   
    
    NSRange effectiveRange;
    NSFont *effectiveFont;
    for (int i = self.selectedRange.location; i < self.selectedRange.location + self.selectedRange.length; i++) {
        effectiveFont = [self.textStorage attribute:NSFontAttributeName atIndex:i effectiveRange:&effectiveRange];
        if (![effectiveFont.fontName hasPrefix:@".AppleColorEmojiUI"]) {
            break;
        }
    }
    
    [self changeFontMarkdown:[NSFontManager.sharedFontManager convertFont:effectiveFont toHaveTrait:NSBoldFontMask] makeBold:YES makeItalic:NO];
    
    // [self.textStorage addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:self.font.pointSize] range:self.selectedRange];
    // [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
}
    
-(void)makeUrl:(id)sender {
    [self.weakd makeUrlOfRange:self.selectedRange];
}

-(void)makeUnderline:(id)sender {
    NSAttributedString *was = [self.attributedString attributedSubstringFromRange:self.selectedRange];
    if ([was length] == 0) {
        return;
    }
    NSRange effectiveRange = NSMakeRange(0, 0);
    id attribute = [was attribute:NSUnderlineStyleAttributeName atIndex:0 effectiveRange:&effectiveRange];

    if(attribute != nil) {
        [self.textStorage removeAttribute:NSUnderlineStyleAttributeName range: self.selectedRange];
    } else {
        [self.textStorage addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:self.selectedRange];
    }
    NSAttributedString *be = [self.attributedString attributedSubstringFromRange:self.selectedRange];

    
    [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
    
    MarkdownUndoItem *item = [[MarkdownUndoItem alloc] initWithAttributedString:was be:be inRange:self.selectedRange];
    [self addItem:item];

}

-(void)makeStrikethrough:(id)sender {
    
    NSAttributedString *was = [self.attributedString attributedSubstringFromRange:self.selectedRange];
    if ([was length] == 0) {
        return;
    }
    NSRange effectiveRange = NSMakeRange(0, 0);
    id attribute = [was attribute:NSStrikethroughStyleAttributeName atIndex:0 effectiveRange:&effectiveRange];

    if(attribute != nil) {
        [self.textStorage removeAttribute:NSStrikethroughStyleAttributeName range: self.selectedRange];
    } else {
        [self.textStorage addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:self.selectedRange];
    }
    
    
    NSAttributedString *be = [self.attributedString attributedSubstringFromRange:self.selectedRange];

    
    [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
    
    MarkdownUndoItem *item = [[MarkdownUndoItem alloc] initWithAttributedString:was be:be inRange:self.selectedRange];
    [self addItem:item];

}
-(void)makeSpoiler:(id)sender {

    NSAttributedString *was = [self.attributedString attributedSubstringFromRange:self.selectedRange];
    
    if ([was length] == 0) {
        return;
    }
    
    NSRange effectiveRange = NSMakeRange(0, 0);
    
    TGInputTextTag * attribute = (TGInputTextTag *) [was attribute:TGSpoilerAttributeName atIndex:0 effectiveRange:&effectiveRange];
    
    if ([attribute.attachment intValue] == inputTagIdSpoiler) {
        [self.textStorage removeAttribute:TGSpoilerAttributeName range:self.selectedRange];
        NSAttributedString *be = [self.attributedString attributedSubstringFromRange:self.selectedRange];
        
        [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];

        MarkdownUndoItem *item = [[MarkdownUndoItem alloc] initWithAttributedString:was be:be inRange:self.selectedRange];
        [self addItem:item];
    } else {
        id tag = [[TGInputTextTag alloc] initWithUniqueId:++nextId attachment:@(inputTagIdSpoiler) attribute:[[TGInputTextAttribute alloc] initWithName:NSForegroundColorAttributeName value:[NSColor redColor]]];
        [self.weakTextView addInputTextTag:tag range:self.selectedRange];
    }
}
    
-(void)addLink:(NSString *)link {
    [self.textStorage addAttribute:NSLinkAttributeName value: link range:self.selectedRange];
}
    
-(void)addLink:(NSString *)link range: (NSRange)range {
    [self.textStorage addAttribute:NSLinkAttributeName value: link range: range];
}
    
-(void)italicWord:(id)sender {
    if(self.selectedRange.length == 0) {
        return;
    }

    NSRange effectiveRange;
    NSFont *effectiveFont;
    for (int i = self.selectedRange.location; i < self.selectedRange.location + self.selectedRange.length; i++) {
        effectiveFont = [self.textStorage attribute:NSFontAttributeName atIndex:i effectiveRange:&effectiveRange];
        if (![effectiveFont.fontName hasPrefix:@".AppleColorEmojiUI"]) {
            break;
        }
    }
    [self changeFontMarkdown:[[NSFontManager sharedFontManager] convertFont:effectiveFont toHaveTrait:NSFontItalicTrait] makeBold:NO makeItalic:YES];
    
    //    [self.textStorage addAttribute:NSFontAttributeName value:[[NSFontManager sharedFontManager] convertFont:[NSFont systemFontOfSize:13] toHaveTrait:NSFontItalicTrait] range:self.selectedRange];
    //    [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
    
}
    
    
-(void)codeWord:(id)sender {
    if(self.selectedRange.length == 0) {
        return;
    }

    [self changeFontMarkdown:[NSFont fontWithName:@"Menlo-Regular" size:self.font.pointSize] makeBold:NO makeItalic:NO];
    //    [self.textStorage addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Menlo-Regular" size:self.font.pointSize] range:self.selectedRange];
    //    [_weakd textViewTextDidChangeSelectedRange:self.selectedRange];
}
    
-(void)changeFontMarkdown:(NSFont *)font makeBold:(BOOL)makeBold makeItalic:(BOOL)makeItalic  {
    
    if(self.selectedRange.length == 0) {
        return;
    }
    
    
    NSAttributedString *was = [self.attributedString attributedSubstringFromRange:self.selectedRange];
    
    NSRange effectiveRange;
    NSFont *effectiveFont;
    for (int i = self.selectedRange.location; i < self.selectedRange.location + self.selectedRange.length; i++) {
        effectiveFont = [self.textStorage attribute:NSFontAttributeName atIndex:i effectiveRange:&effectiveRange];
        if (![effectiveFont.fontName hasPrefix:@".AppleColorEmojiUI"]) {
            break;
        }
    }
    
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
        
        NSFont *newFont = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:makeBold ? NSBoldFontMask : makeItalic ? NSItalicFontMask : 0];
        
        if (self.selectedRange.location >= effectiveRange.location && self.selectedRange.location + self.selectedRange.length <= effectiveRange.location + effectiveRange.length) {
            [self.textStorage addAttribute:NSFontAttributeName value:newFont range:self.selectedRange];
        } else if (self.selectedRange.location >= effectiveRange.location) {
            [self.textStorage addAttribute:NSFontAttributeName value:font range:self.selectedRange];
        } else {
            [self.textStorage addAttribute:NSFontAttributeName value:newFont range:self.selectedRange];
        }
    };
    
    BOOL doNext = YES;
    
    if (isBold) {
        if (isEffectiveBold && makeBold) {
            block();
            doNext = NO;
        } else {
            [self.textStorage addAttribute:NSFontAttributeName value:font range:self.selectedRange];
        }
    }
    if (isItalic) {
        if (isEffectiveItalic && makeItalic) {
            block();
        } else if (doNext) {
            [self.textStorage addAttribute:NSFontAttributeName value:font range:self.selectedRange];
            doNext = NO;
        }
    }
    if (isMonospace) {
        if (isEffectiveMonospace) {
            block();
        } else if (doNext) {
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
    
- (void)addSimpleItem:(SimpleUndoItem *)item {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(removeSimpleItem:) object:item];
    if (![[self undoManager] isUndoing]) {
        [[self undoManager] setActionName:NSLocalizedString(@"actions.add-item", @"Add Item")];
    }
    [[self textStorage] setAttributedString:item.be];
    [self setSelectedRange:item.beRange];
    [self.weakd textViewTextDidChangeSelectedRange:self.selectedRange];
}
    
- (void)removeSimpleItem:(SimpleUndoItem *)item {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(addSimpleItem:) object:item];
    if (![[self undoManager] isUndoing]) {
        [[self undoManager] setActionName:NSLocalizedString(@"actions.remove-item", @"Remove Item")];
    }
    [[self textStorage] setAttributedString:item.was];
    [self setSelectedRange:item.wasRange];
    [self.weakd textViewTextDidChangeSelectedRange:item.wasRange];
    [self.weakTextView update:YES];
}
    
    
    
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if(menuItem.action == @selector(changeLayoutOrientation:)) {
        return NO;
    }
    
    if(menuItem.action == @selector(copy:)) {
        return self.selectedRange.length > 0;
    }
    
    return [super validateMenuItem:menuItem];
}
    
-(void)copy:(id)sender {
    if (self.selectedRange.length > 0) {
        if ([self.weakd respondsToSelector:@selector(copyTextWithRTF:)]) {
            if (![self.weakd copyTextWithRTF: [self.attributedString attributedSubstringFromRange:self.selectedRange]]) {
                [super copy:sender];
            }
        } else {
            [super copy:sender];
        }
    }
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
    
-(void)insertNewline:(id)sender {
    [super insertNewline:sender];
}


    
- (void) keyDown:(NSEvent *)theEvent {
    
    if(_weakd.textViewIsTypingEnabled) {
        
        if(isEnterEvent(theEvent) && !(self.hasMarkedText)) {
            
            BOOL result = [_weakd textViewEnterPressed:theEvent];
            
            if ((!result && (theEvent.modifierFlags & NSEventModifierFlagCommand)) || (!result && (theEvent.modifierFlags & NSEventModifierFlagShift))) {
                [super insertNewline:self];
                return;
            }
            
            if (result) {
                return;
            }
        } else if(theEvent.keyCode == 53 && [_weakd respondsToSelector:@selector(textViewNeedClose:)]) {
            [_weakd textViewNeedClose:self];
            return;
        }
        
        if (!(theEvent.modifierFlags & NSEventModifierFlagCommand) || !isEnterEvent(theEvent)) {
            [super keyDown:theEvent];
        }
    } else if(_weakd == nil) {
        [super keyDown:theEvent];
    }
    
}
    
-(void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
}
    
    
    
    
-(void)setString:(NSString *)string {
    [super setString:string];
}
    
@end



@implementation TGTextFieldPlaceholder
    
-(void)drawRect:(NSRect)dirtyRect {
    
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext]
                                          graphicsPort];
    
    BOOL isRetina = self.window.backingScaleFactor == 2.0;
    
    if (isRetina) {
        CGContextSetAllowsAntialiasing(context, true);
        CGContextSetShouldSmoothFonts(context, false);
        CGContextSetAllowsFontSmoothing(context, false);
    }
    [super drawRect:dirtyRect];
    
}
    
-(NSMenu *)menuForEvent:(NSEvent *)event {
    return [self.superview menuForEvent:event];
}

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

-(void)mouseDown:(NSEvent *)event {
    [super mouseDown:event];
}
    
@end


@interface TGModernGrowingTextView () <NSTextViewDelegate,CAAnimationDelegate, NSLayoutManagerDelegate> {
    int _last_height;
}
    @property (nonatomic,strong) TGGrowingTextView *textView;
    @property (nonatomic,strong) NSScrollView *scrollView;
    @property (nonatomic,assign) BOOL notify_next;
    @property (nonatomic, strong) NSUndoManager *_undo;
    @property (nonatomic, strong) NSView * _Nullable (^ _Nullable getAttachView)();
    @property (nonatomic,strong) NSMutableDictionary<NSString *, NSView *> *attachments;

@end

@interface TGTextLayoutManager : NSLayoutManager

@end

@implementation TGTextLayoutManager

-(void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
    [super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
}

@end


@implementation TGModernGrowingTextView
    
    
-(instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [self initWithFrame: frameRect unscrollable: false]) {
        
    }
    return self;
}
    
-(instancetype)initWithFrame:(NSRect)frameRect unscrollable:(BOOL)unscrollable {
    if(self = [super initWithFrame:frameRect]) {
        
        _min_height = 34;
        _max_height = 200;
        _animates = YES;
        _cursorColor = [NSColor blackColor];
//        _textStorage = [[NSTextStorage alloc] init];
//
//        TGTextLayoutManager *layoutManager = [[TGTextLayoutManager alloc] init];
//        [_textStorage addLayoutManager:layoutManager];
//
//        NSTextContainer *container = [[NSTextContainer alloc] init];
//        container.widthTracksTextView = true;
//        container.heightTracksTextView = true;
//        [layoutManager addTextContainer:container];
//
        _textView = [[[self _textViewClass] alloc] initWithFrame:self.bounds];

        _attachments = [[NSMutableDictionary alloc] init];
        
        [_textView setRichText:NO];
        [_textView setImportsGraphics:NO];
        _textView.insertionPointColor = _cursorColor;
        [_textView setAllowsUndo:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionDidChanged:) name:NSTextViewDidChangeSelectionNotification object:_textView];
        
        self._undo = [[NSUndoManager alloc] init];
        self.textView.undo = self._undo;
        self.autoresizesSubviews = YES;
        _textView.delegate = self;
        
        [_textView setDrawsBackground:NO];
        
        
        _textView.layoutManager.delegate = self;
        
        if (unscrollable) {
            self.scrollView = [[UnscrollableTextScrollView alloc] initWithFrame:self.bounds];
        } else {
            self.scrollView = [[GrowingScrollView alloc] initWithFrame:self.bounds];
        }
        
        
        [[self.scrollView verticalScroller] setControlSize:NSControlSizeSmall];
        self.scrollView.documentView = _textView;
        [self.scrollView setFrame:NSMakeRect(0, 0, NSWidth(self.frame), NSHeight(self.frame))];
        [self addSubview:self.scrollView];
        
        
        [self.scrollView setDrawsBackground:NO];
        self.wantsLayer = _textView.wantsLayer = _scrollView.wantsLayer = YES;
        
        
        _placeholder = [[TGTextFieldPlaceholder alloc] init];
        _placeholder.layer.opacity = 0.7;
        _placeholder.wantsLayer = YES;
        [_placeholder setBordered:NO];
        [_placeholder setDrawsBackground:NO];
        [_placeholder setSelectable:NO];
        [_placeholder setEditable:NO];
        [_placeholder setEnabled:NO];
        [_placeholder setContinuous:NO];
        
        [_placeholder setLineBreakMode:NSLineBreakByTruncatingTail];
        [_placeholder setMaximumNumberOfLines:0];
        
        [[_placeholder cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [[_placeholder cell] setTruncatesLastVisibleLine:YES];
        
        [self addSubview:_placeholder];
        
        _textView.weakTextView = self;
        
        
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

-(void)setSelectTextColor:(NSColor *)selectTextColor {
    _selectedTextColor = selectTextColor;
    [self refreshAttributes];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate textViewTextDidChangeSelectedRange:self.textView.selectedRange];
        });
        self._selectedRange = self.textView.selectedRange;
    }
    
    NSRect newRect = [_textView.layoutManager usedRectForTextContainer:_textView.textContainer];
    
    NSSize size = newRect.size;
    size.width = NSWidth(self.frame);
    NSSize newSize = NSMakeSize(size.width, size.height);
    newSize.height+= 2;
    newSize.height = MIN(MAX(newSize.height,_min_height),_max_height);
    
    [self updatePlaceholder:self.animates newSize:newSize];
    
    [self refreshAttachments];
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
    [self refreshAttributes];
}


-(void)refreshAttachments {
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSMutableArray<TGTextAttachment *> *attachments = [NSMutableArray array];

    
    NSRange range = NSMakeRange(0, self.textView.attributedString.length);
        
    [self.textView.attributedString enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        
        [attrs enumerateKeysAndObjectsUsingBlock:^(NSAttributedStringKey  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([key isEqualToString:TGAnimatedEmojiAttributeName]) {
                TGTextAttachment *attachment = (TGTextAttachment *)obj;
                if (attachment) {
                    [ranges addObject:[NSValue valueWithRange:range]];
                    [attachments addObject:obj];
                }
            }
        }];
        
    }];
    
    NSMutableArray<NSString *> *validIds = [NSMutableArray array];
    
    for (int i = 0; i < ranges.count; i++) {
        NSRange range = ranges[i].rangeValue;
        TGTextAttachment *attachment = attachments[i];
        
        NSRect rect = [self.textView highlightRectForRange:range whole:NO];
        NSView* view = [self.attachments valueForKey:attachment.identifier];
        if (view == nil) {
            view = _getAttachView(attachment, rect.size);
        }
        if (view != nil) {
            rect.size.height = view.frame.size.height;
            rect.size.width = view.frame.size.width;
            rect.origin.y -= 1;
            rect.origin.y = floor(rect.origin.y);
            rect.origin.x = floor(rect.origin.x);
            view.frame = rect;
            if(view != nil && view.superview != _textView) {
                [_textView addSubview:view];
            }
            [validIds addObject:attachment.identifier];
            [_attachments setObject:view forKey:attachment.identifier];
        }
    }
    
    NSMutableArray<NSString *> *toRemove = [NSMutableArray array];
    [_attachments enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSView * _Nonnull obj, BOOL * _Nonnull stop) {
        if (![validIds containsObject:key]) {
            [toRemove addObject:key];
        }
    }];
    
    for (int i = 0; i < toRemove.count; i++) {
        NSView *view = [_attachments objectForKey:toRemove[i]];
        [view removeFromSuperview];
        [_attachments removeObjectForKey:toRemove[i]];
    }
    
        
    [self.textView.attributedString enumerateAttribute:TGAnimatedEmojiAttributeName inRange:range options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
        if ([value isKindOfClass:[TGTextAttachment class]]) {
            [ranges addObject:[NSValue valueWithRange:range]];
        }
    }];
    
    for (int i = 0; i < ranges.count; i++) {
        NSRange range = [[ranges objectAtIndex:i] rangeValue];
        [self.textView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor clearColor] range:range];
    }
    
}
    
-(void)installGetAttachView:(NSView* _Nullable (^)(TGTextAttachment * _Nonnull, NSSize size))getAttachView {
    _getAttachView = getAttachView;
}
    
-(NSArray<NSTouchBarItemIdentifier> *)textView:(NSTextView *)textView shouldUpdateTouchBarItemIdentifiers:(NSArray<NSTouchBarItemIdentifier> *)identifiers {
    if ([self.delegate respondsToSelector:@selector(textView:shouldUpdateTouchBarItemIdentifiers:)]) {
        return [self.delegate textView: textView shouldUpdateTouchBarItemIdentifiers: identifiers];
    }
    return identifiers;
}
    
- (void)textDidChange:(NSNotification *)notification {
    int limit = self.delegate == nil ? INT32_MAX : [self.delegate maxCharactersLimit: self];
    
    if (self.string != nil && self.string.length > 0 && self.string.length > limit) {
        
        NSAttributedString *string = [self.attributedString attributedSubstringFromRange:NSMakeRange(0, MIN(limit, self.attributedString.string.length))];
        
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithAttributedString: string];
        NSRange selectedRange = _textView.selectedRange;
        [_textView.textStorage setAttributedString:attr];
        [self update:notification != nil];
        [self setSelectedRange:NSMakeRange(MIN(selectedRange.location, string.length), 0)];
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
    
    if(notification.object) {
        NSString *text = self.string;
        [self.delegate textViewTextDidChange:text];
        if (![text isEqualToString:self.string]) {
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
    
    BOOL animated = self.animates && ![self.window inLiveResize] && self.window != nil;
    
    
    if(_last_height != newSize.height) {
        
        dispatch_block_t future = ^ {
            
            _last_height = newSize.height;
            if (notification.object != nil) {
                [_delegate textViewHeightChanged:(CGFloat)newSize.height animated:animated];
            }
        };
        
        [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
        
        
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
        
    } else {
        int bp = 0;
        bp += 1;
    }
    
    
    //   if(self._needShowPlaceholder) {
    
    [self updatePlaceholder: animated newSize: newSize];
    
    
    [self setNeedsDisplay:YES];
    
    if (_textView.selectedRange.location != NSNotFound) {
        [self setSelectedRange:_textView.selectedRange];
    }
    
    [self setNeedsDisplay:YES];
    
    
    [_textView setNeedsDisplay:YES];
    
    [self refreshAttributes];
    
}
 
    
-(void)scrollToCursor {
    [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
    
    NSRect lineRect = [self.textView highlightRectForRange:NSMakeRange(self.selectedRange.location + self.selectedRange.length - 1, 1) whole:true];
    
    CGFloat maxY = [self.scrollView.contentView documentRect].size.height;
    maxY = MIN(MAX(lineRect.origin.y, 0), maxY - self.scrollView.frame.size.height);
    
    NSPoint point = NSMakePoint(lineRect.origin.x, maxY);
    if (!NSPointInRect(lineRect.origin, _scrollView.documentVisibleRect) && _scrollView.documentVisibleRect.size.width > 0) {
        [self.scrollView.contentView scrollToPoint:point];
    }
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
            [self addSubview:_placeholder];
            
            CABasicAnimation *oAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
            oAnim.fromValue = @(presentOpacity);
            oAnim.toValue = @(self._needShowPlaceholder ? 1.0f : 0.0f);
            oAnim.duration = 0.2;
            oAnim.removedOnCompletion = YES;
            oAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            
            oAnim.delegate = self;
            
            [_placeholder.layer removeAnimationForKey:@"opacity"];
            [_placeholder.layer addAnimation:oAnim forKey:@"opacity"];
            
            
            NSPoint toPoint = self._needShowPlaceholder ? NSMakePoint(self._startXPlaceholder, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0))) : NSMakePoint(self._endXPlaceholder, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0)));
            
            
            CABasicAnimation *pAnim = [CABasicAnimation animationWithKeyPath:@"position"];
            pAnim.removedOnCompletion = YES;
            pAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            pAnim.duration = 0.2;
            pAnim.fromValue = [NSValue valueWithPoint:NSMakePoint(presentX, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0)))];
            pAnim.toValue =  [NSValue valueWithPoint:toPoint];
            
            pAnim.delegate = self;
            [_placeholder.layer removeAnimationForKey:@"position"];
            [_placeholder.layer addAnimation:pAnim forKey:@"position"];
            
        } else {
            if (_placeholder.layer.animationKeys.count == 0) {
                if (self._needShowPlaceholder) {
                    [self addSubview:_placeholder];
                } else {
                    [_placeholder removeFromSuperview];
                }
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
    
-(void)setMax_height:(int)max_height {
    self->_max_height = max_height;
    [_scrollView setFrame:NSMakeRect(0, 0, NSWidth(_scrollView.frame), MIN(NSHeight(_scrollView.frame), (CGFloat)max_height))];
}
    
-(void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if (self._needShowPlaceholder) {
        [self addSubview:_placeholder];
    } else {
        [_placeholder removeFromSuperview];
    }
}
    
-(void)addSubview:(NSView *)view {
    [super addSubview:view];
}
    
-(void)setLinkColor:(NSColor *)linkColor {
    _linkColor = linkColor;
}
    
-(void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_scrollView setFrame:NSMakeRect(0, 0, newSize.width, newSize.height)];
    [_textView setFrame:NSMakeRect(0, 0, NSWidth(_scrollView.frame), NSHeight(_textView.frame))];
    
    
    NSSize size = [_placeholder.attributedStringValue size];
    [_placeholder setFrameSize:NSMakeSize(MIN(NSWidth(_textView.frame) - self._startXPlaceholder, size.width + 10), size.height)];
    [_placeholder setFrameOrigin:self._needShowPlaceholder ? NSMakePoint(self._startXPlaceholder, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0))) : NSMakePoint(NSMinX(_placeholder.frame) + 30, fabsf(roundf((newSize.height - NSHeight(_placeholder.frame))/2.0)))];
}
    
-(BOOL)_needShowPlaceholder {
    return self.string.length == 0 && _placeholderAttributedString && !_textView.hasMarkedText;
}
    
-(void)setPlaceholderAttributedString:(NSAttributedString *)placeholderAttributedString update:(BOOL)update {
    
    if([_placeholderAttributedString isEqualToAttributedString:placeholderAttributedString])
    return;
    
    
    
    [_placeholder setAttributedStringValue:placeholderAttributedString];
    
    _placeholderAttributedString = placeholderAttributedString;
    [_placeholder setAttributedStringValue:placeholderAttributedString];
    
    
   // [_placeholder sizeToFit];
    NSSize size = [_placeholder.attributedStringValue size];
    [_placeholder setFrameSize:NSMakeSize(MIN(NSWidth(_textView.frame) - self._startXPlaceholder - 10, size.width + 10), size.height)];
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
        
        
        
        [self.textView.textStorage addAttribute:NSForegroundColorAttributeName value:self.textColor range:NSMakeRange(0, string.length)];
       
        if (self.selectedTextColor != nil) {
            [_textView setSelectedTextAttributes:
                 [NSDictionary dictionaryWithObjectsAndKeys:
                  self.selectedTextColor, NSBackgroundColorAttributeName,
                  nil]];
        }
        
        [string enumerateAttribute:TGEmojiHolderAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
            TGInputTextEmojiHolder *attribute = (TGInputTextEmojiHolder *)value;
            if (attribute) {
                [self.textView.textStorage addAttribute:attribute.attribute.name value:attribute.attribute.value range:range];
            }
        }];
        
        NSArray<NSString *> *attributes = @[TGCustomLinkAttributeName, TGSpoilerAttributeName];
        
        for (int i = 0; i < attributes.count; i++) {
            NSString *attributeName = attributes[i];
            
            __block NSMutableArray<TGInputTextTagAndRange *> *inputTextTags = [[NSMutableArray alloc] init];
            [string enumerateAttribute:attributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
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
                    [self.textView.textStorage removeAttribute:attributeName range:tagAndRange.range];
                    
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
                        [self.textView.textStorage removeAttribute:attributeName range:tagAndRange.range];
                        
                        [self.textView.textStorage addAttribute:attributeName value:tagAndRange.tag range:updatedRange];
                        
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
                            [self.textView.textStorage removeAttribute:attributeName range:tagAndRange.range];
                            
                            [self.textView.textStorage addAttribute:attributeName value:tagAndRange.tag range:updatedRange];
                            
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
                                if (candidateStart > 0 && [alphanumericSet characterIsMember:[string.string characterAtIndex:candidateStart - 1]]) {
                                    while (j < candidateEnd) {
                                        unichar c = [string.string characterAtIndex:j];
                                        NSCharacterSet *alphanumericSet = [NSCharacterSet alphanumericCharacterSet];
                                        if (![alphanumericSet characterIsMember:c]) {
                                            break;
                                        }
                                        j++;
                                    }
                                }
                                if (j == candidateStart) {
                                    [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                    [self.textView.textStorage addAttribute:tagAndRange.tag.attribute.name value:tagAndRange.tag.attribute.value range:tagAndRange.range];
                                } else {
                                    [self.textView.textStorage removeAttribute:attributeName range:tagAndRange.range];
                                    
                                    NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                    [self.textView.textStorage addAttribute:attributeName value:tagAndRange.tag range:updatedRange];
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
                                    [self.textView.textStorage removeAttribute:attributeName range:tagAndRange.range];
                                    
                                    [self.textView.textStorage removeAttribute:attributeName range:nextTagAndRange.range];
                                    
                                    NSRange updatedRange = NSMakeRange(tagAndRange.range.location, nextTagAndRange.range.location + nextTagAndRange.range.length - tagAndRange.range.location);
                                    
                                    [self.textView.textStorage addAttribute:attributeName value:tagAndRange.tag range:updatedRange];
                                    
                                    inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                    [inputTextTags removeObjectAtIndex:i + 1];
                                    
                                    i--;
                                } else if (j != candidateStart) {
                                    [self.textView.textStorage removeAttribute:attributeName range:tagAndRange.range];
                                    
                                    NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                    [self.textView.textStorage addAttribute:attributeName value:tagAndRange.tag range:updatedRange];
                                    
                                    inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                    
                                    i--;
                                } else {
                                    [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                    [self.textView.textStorage addAttribute:tagAndRange.tag.attribute.name value:tagAndRange.tag.attribute.value range:tagAndRange.range];
                                }
                            }
                        }
                    }
                }
            }

        }
        
        [self setSelectedRange:self.selectedRange];

    } @catch (NSException *exception) {
        
    }
    
    [self refreshAttachments];
}

-(void)strikethroughWord {
    [self.textView makeStrikethrough:nil];
}
-(void)underlineWord {
    [self.textView makeUnderline:nil];
}
-(void)spoilerWord {
    [self.textView makeSpoiler:nil];

}
    
-(void)boldWord {
    [self.textView boldWord:nil];

}
-(void)removeAllAttributes {
    if(self.selectedRange.length == 0) {
        return;
    }
    NSMutableAttributedString *attr = [self.textView.attributedString mutableCopy];
    [attr setAttributes:nil range:self.selectedRange];
    [attr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:self.textFont.pointSize] range: self.selectedRange];
    [self.textView.textStorage setAttributedString:attr];
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
    int limit = self.delegate == nil ? INT32_MAX : [self.delegate maxCharactersLimit: self];
    
    NSAttributedString *string = [attributedString attributedSubstringFromRange:NSMakeRange(0, MIN(limit, attributedString.string.length))];
    
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithAttributedString: string];
        
    [string enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(NSFont *value, NSRange range, BOOL * _Nonnull stop) {
        [attr addAttribute:NSFontAttributeName value:[[NSFontManager sharedFontManager] convertFont:value toSize:_textFont.pointSize] range:range];
    }];
        
    NSRange selectedRange = _textView.selectedRange;
    if (selectedRange.location == self.textView.string.length) {
        selectedRange = NSMakeRange(attr.length, 0);
    }
    [_textView.textStorage setAttributedString:attr];
    

    BOOL o = self.animates;
    self.animates = animated;
    [self update:animated];
    self.animates = o;
   
    [self setSelectedRange:NSMakeRange(MIN(selectedRange.location, string.length), 0)];
    
    [self refreshAttachments];
    
}
    
    
-(void)setString:(NSString *)string {
    
    if (![string isEqualToString:self.string]) {
        [self setString:string animated:self.animates];
    }
}
    
-(void)setString:(NSString *)string animated:(BOOL)animated {
    BOOL o = self.animates;
    self.animates = animated;
    [_textView setString:string];
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
    
- (void)addSimpleItem:(SimpleUndoItem *)item {
    [self.inputView addSimpleItem:item];
    [self update: YES];
}
    
-(void)addInputTextTag:(TGInputTextTag *)tag range:(NSRange)range {
    NSAttributedString *was = [self.textView.textStorage attributedSubstringFromRange:range];
    [_textView.textStorage addAttribute:TGCustomLinkAttributeName value:tag range:range];
    MarkdownUndoItem *item = [[MarkdownUndoItem alloc] initWithAttributedString:was be:[self.textView.textStorage attributedSubstringFromRange:range] inRange:range];
    [self.textView addItem:item];
}
    
    
-(void)addLink:(NSString *)link {
    if (self.selectedRange.length == 0)
        return;
    if (link == nil) {
        NSMutableAttributedString *copy = [self.attributedString mutableCopy];
        [copy removeAttribute:TGCustomLinkAttributeName range: self.selectedRange];
        [self setAttributedString:copy animated:false];
    } else {
        id tag = [[TGInputTextTag alloc] initWithUniqueId:++nextId attachment:link attribute:[[TGInputTextAttribute alloc] initWithName:NSForegroundColorAttributeName value:_linkColor]];
        [self addInputTextTag:tag range:self.selectedRange];
        [self update:YES];
    }
   
}
    
-(void)addLink:(NSString *)link range: (NSRange)range {
    if (range.length == 0)
        return;
    
    if (link == nil) {
        NSMutableAttributedString *copy = [self.attributedString mutableCopy];
        [copy removeAttribute:TGCustomLinkAttributeName range: range];
        [self setAttributedString:copy animated:false];
    } else {
        id tag = [[TGInputTextTag alloc] initWithUniqueId:++nextId attachment:link attribute:[[TGInputTextAttribute alloc] initWithName:NSForegroundColorAttributeName value:_linkColor]];
        [self addInputTextTag:tag range:range];
        [self update:YES];
    }
}

-(void)addLink:(NSString *_Nullable)link text: (NSString * __nonnull)text range: (NSRange)range {
    if (link == nil) {
        NSMutableAttributedString *copy = [self.attributedString mutableCopy];
        [copy replaceCharactersInRange:range withString:text];
        [copy removeAttribute:TGCustomLinkAttributeName range: range];
        [self setAttributedString:copy animated:false];
    } else {
        
        id tag = [[TGInputTextTag alloc] initWithUniqueId:++nextId attachment:link attribute:[[TGInputTextAttribute alloc] initWithName:NSForegroundColorAttributeName value:_linkColor]];
        
        NSAttributedString *was = [self.attributedString mutableCopy];
        
        NSMutableAttributedString *be = [self.attributedString mutableCopy];
        [be addAttribute:TGCustomLinkAttributeName value:tag range: range];
        [be replaceCharactersInRange:range withString:text];

        SimpleUndoItem *item = [[SimpleUndoItem alloc] initWithAttributedString:was be:be wasRange:range beRange:NSMakeRange(range.location, text.length)]; //[[SimpleUndoItem alloc] initWithAttributedString:was be:be inRange:range];
        [self addSimpleItem:item];

        [self update:YES];
    }
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
    
-(void)rightMouseDown:(NSEvent *)event {
    [super rightMouseDown:event];
}
    
-(NSMenu *)menuForEvent:(NSEvent *)event {
    return [self.textView menuForEvent:event];
}
    
-(id)validRequestorForSendType:(NSPasteboardType)sendType returnType:(NSPasteboardType)returnType {
    return [self.textView validRequestorForSendType:sendType returnType:returnType];
    
}
    
-(BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard {
    [self.delegate textViewDidPaste:pboard];
    return YES;
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

-(void)setBackgroundColor:(NSColor * __nonnull)color {
    self.scrollView.backgroundColor = color;
    self.textView.backgroundColor = color;
    _placeholder.backgroundColor = [NSColor clearColor];
}

-(NSRect)highlightRectForRange:(NSRange)aRange whole: (BOOL)whole {
    return [self.textView highlightRectForRange:aRange whole:whole];
}

-(NSScrollView *)scroll {
    return self.scrollView;
}

@end

