// MIHSliderView.m
//
// Copyright (c) 2013 Michael Hohl. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MIHSliderView.h"

const NSTimeInterval kDefaultScheduledTransitionTimeInterval = 4.0;
const NSTimeInterval kDefaultTransitionAnimationDuration = 0.6;

@interface MIHSliderView () // private API
@property (assign) NSUInteger indexOfDisplayedSlide;
@property (retain) NSView *displayedSlide;
@property (retain) NSTimer *transitionTimer;
@property (retain) NSView *contentView;
@property (assign) CGFloat scrollDeltaX;
@property (assign) CGFloat scrollDeltaY;
- (void)_prepareView;
- (void)_prepareTransitionTimer;
- (void)_prepareTransitionToIndex:(NSUInteger)index;
- (void)_handleTimerTick:(id)userInfo;
- (void)_dotViewSelected:(NSImageView *)dotView;
@end

@interface MIHSliderDotsControl () // private API
@property (nonatomic, assign) NSUInteger dotsCount;
@property (nonatomic, assign) NSUInteger indexOfHighlightedDot;
@property (assign) MIHSliderView *sliderView;
@end

@implementation MIHSliderView {
    NSMutableArray *_slides;
    NSTimeInterval _scheduledTransitionInterval;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self _prepareView];
        _slides = [[NSMutableArray alloc] init];
        _transitionStyle = MIHSliderTransitionFade;
        _scheduledTransitionInterval = kDefaultScheduledTransitionTimeInterval;
        _transitionAnimationDuration = kDefaultTransitionAnimationDuration;
        _repeatingScheduledTransition = YES;
        self.scheduledTransition = YES;
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self _prepareView];
        _slides = [[NSMutableArray alloc] init];
        _transitionStyle = MIHSliderTransitionFade;
        _scheduledTransitionInterval = kDefaultScheduledTransitionTimeInterval;
        _transitionAnimationDuration = kDefaultTransitionAnimationDuration;
        _repeatingScheduledTransition = YES;
        self.scheduledTransition = YES;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _prepareView];
        _slides = [[NSMutableArray alloc] initWithArray:[aDecoder decodeObjectForKey:@"_slides"]];
        self.indexOfDisplayedSlide = [aDecoder decodeIntegerForKey:@"indexOfDisplayedSlide"];
        _transitionStyle = [aDecoder decodeIntForKey:@"_transitionStyle"];
        _scheduledTransitionInterval = [aDecoder decodeDoubleForKey:@"_scheduledTransitionInterval"];
        _transitionAnimationDuration = [aDecoder decodeDoubleForKey:@"_transitionAnimationDuration"];
        _repeatingScheduledTransition = [aDecoder decodeBoolForKey:@"_repeatingScheduledTransition"];
        _dotsControl = [aDecoder decodeObjectForKey:@"_dotsControl"];
        self.scheduledTransition = [aDecoder decodeBoolForKey:@"scheduledTransition"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_slides forKey:@"_slides"];
    [aCoder encodeInteger:self.indexOfDisplayedSlide forKey:@"indexOfDisplayedSlide"];
    [aCoder encodeInt:_transitionStyle forKey:@"_transitionStyle"];
    [aCoder encodeDouble:_scheduledTransitionInterval forKey:@"_scheduledTransitionInterval"];
    [aCoder encodeDouble:_transitionAnimationDuration forKey:@"_transitionAnimationDuration"];
    [aCoder encodeBool:_repeatingScheduledTransition forKey:@"_repeatingScheduledTransition"];
    [aCoder encodeObject:_dotsControl forKey:@"_dotsControl"];
    [aCoder encodeBool:self.scheduledTransition forKey:@"scheduledTransition"];
    [super encodeWithCoder:aCoder];
}

#pragma mark -

- (void)addSlide:(NSView *)aSlide
{
    [_slides addObject:aSlide];
    if ([_slides count] == 1) {
        [self displaySlideAtIndex:0];
    }
    self.dotsControl.dotsCount = self.slides.count;
}

- (void)removeSlide:(NSView *)aSlide
{
    [_slides removeObject:aSlide];
    if (self.indexOfDisplayedSlide >= [_slides count]) {
        self.indexOfDisplayedSlide = 0;
    }
    self.dotsControl.dotsCount = self.slides.count;
}

#pragma mark -

- (void)displaySlideAtIndex:(NSUInteger)aIndex
{
    self.dotsControl.indexOfHighlightedDot = aIndex;
    
    NSView *slideToDisplay = [self.slides objectAtIndex:aIndex];
    if (slideToDisplay == self.displayedSlide) return;
    slideToDisplay.frame = self.bounds;
    [slideToDisplay setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    if (self.displayedSlide == nil) {
        [self.contentView addSubview:slideToDisplay];
        self.displayedSlide = slideToDisplay;
        self.indexOfDisplayedSlide = aIndex;
        return;
    }
    
    [NSAnimationContext beginGrouping];
    [self _prepareTransitionToIndex:aIndex];
    [[self.contentView animator] replaceSubview:self.displayedSlide with:slideToDisplay];
    [NSAnimationContext endGrouping];
    
    self.displayedSlide = slideToDisplay;
    self.indexOfDisplayedSlide = aIndex;
}

- (void)setScheduledTransition:(BOOL)scheduledTransition
{
    if (scheduledTransition) {
        [self _prepareTransitionTimer];
    } else {
        [self.transitionTimer invalidate];
        self.transitionTimer = nil;
    }
}

- (BOOL)scheduledTransition
{
    return (self.transitionTimer != nil);
}

- (void)setScheduledTransitionInterval:(NSTimeInterval)scheduledTransitionInterval
{
    _scheduledTransitionInterval = scheduledTransitionInterval;
    if (self.scheduledTransition) {
        [self _prepareTransitionTimer];
    }
}

- (NSTimeInterval)scheduledTransitionInterval
{
    return _scheduledTransitionInterval;
}

- (void)scrollWheel:(NSEvent *)theEvent {
    if (theEvent.phase == NSEventPhaseBegan) {
        self.scrollDeltaX = 0;
        self.scrollDeltaY = 0;
    } else if (theEvent.phase == NSEventPhaseChanged) {
        self.scrollDeltaX += theEvent.scrollingDeltaX;
        self.scrollDeltaY += theEvent.scrollingDeltaY;
        if (self.scrollDeltaY == 0) {
            [super scrollWheel:theEvent];
        }
    } else if (theEvent.phase == NSEventPhaseEnded) {
        if (self.scrollDeltaX > 50) {
            self.transitionStyle = MIHSliderTransitionPushHorizontalFromLeft;
            [self displaySlideAtIndex:(self.indexOfDisplayedSlide - 1) % self.slides.count];
            if (self.scheduledTransition) {
                [self _prepareTransitionTimer];
            }
        } else if (self.scrollDeltaX < - 50) {
            self.transitionStyle = MIHSliderTransitionPushHorizontalFromRight;
            [self displaySlideAtIndex:(self.indexOfDisplayedSlide + 1) % self.slides.count];
            if (self.scheduledTransition) {
                [self _prepareTransitionTimer];
            }
        }
    } else if (theEvent.phase == NSEventPhaseCancelled) {
        self.scrollDeltaX = 0;
        self.scrollDeltaY = 0;
    } else {
        [super scrollWheel:theEvent];
    }
}

#pragma mark -

- (void)_prepareView
{
    [self setAcceptsTouchEvents:YES];
    self.contentView = [[NSView alloc] initWithFrame:self.bounds];
    self.contentView.wantsLayer = YES;
    [self addSubview:self.contentView];
    _dotsControl = [[MIHSliderDotsControl alloc] init];
    _dotsControl.sliderView = self;
    _dotsControl.normalDotImage = [NSImage imageNamed:@"Icon_SliderNormal"];
    _dotsControl.highlightedDotImage = [NSImage imageNamed:@"Icon_SliderHighlighted"];
    _dotsControl.wantsLayer = YES;
    [self addSubview:_dotsControl positioned:NSWindowAbove relativeTo:self.contentView];
}

- (void)_handleTimerTick:(id)userInfo
{
    if (self.slides.count > 0 && (_repeatingScheduledTransition || self.indexOfDisplayedSlide + 1 < self.slides.count)) {
        [self displaySlideAtIndex:(self.indexOfDisplayedSlide + 1) % self.slides.count];
    }
}


- (void)_dotViewSelected:(NSView *)dotView
{
    if (self.scheduledTransition) {
        [self _prepareTransitionTimer]; // <- this will restart the timer
    }
    if (dotView.tag >= 0 && dotView.tag < self.slides.count) {

        self.transitionStyle = dotView.tag > self.dotsControl.indexOfHighlightedDot ? MIHSliderTransitionPushHorizontalFromRight: MIHSliderTransitionPushHorizontalFromLeft;

        [self displaySlideAtIndex:dotView.tag];
    }
}

- (void)_prepareTransitionToIndex:(NSUInteger)aIndex
{
    const CFTimeInterval duration = self.transitionAnimationDuration * ([self.window currentEvent].modifierFlags & NSShiftKeyMask) ? 1.5 : 0.3;
    CATransition *transition = [CATransition animation];
    [transition setDuration:duration];
    [transition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    switch (self.transitionStyle) {
        case MIHSliderTransitionFade:
            [transition setType:kCATransitionFade];
            break;
            
        case MIHSliderTransitionPushHorizontalFromLeft:
            [transition setType:kCATransitionPush];
            //[transition setSubtype:(self.indexOfDisplayedSlide < aIndex ? kCATransitionFromRight : kCATransitionFromLeft)];
            [transition setSubtype:kCATransitionFromLeft];
            break;
        case MIHSliderTransitionPushHorizontalFromRight:
            [transition setType:kCATransitionPush];
            //[transition setSubtype:(self.indexOfDisplayedSlide < aIndex ? kCATransitionFromRight : kCATransitionFromLeft)];
            [transition setSubtype:kCATransitionFromRight];
            break;
        case MIHSliderTransitionPushVertical:
            [transition setType:kCATransitionMoveIn];
            //[transition setSubtype:(self.indexOfDisplayedSlide < aIndex ? kCATransitionFromTop : kCATransitionFromBottom)];
            [transition setSubtype:kCATransitionFromTop];
            break;
    }
    [self.contentView setAnimations:[NSDictionary dictionaryWithObject:transition forKey:@"subviews"]];
}

- (void)_prepareTransitionTimer
{
    [self.transitionTimer invalidate];
    self.transitionTimer = [NSTimer scheduledTimerWithTimeInterval:self.scheduledTransitionInterval
                                                            target:self
                                                          selector:@selector(_handleTimerTick:)
                                                          userInfo:nil
                                                           repeats:YES];
}

@end

const CGFloat kDotImageSize = 15.0;
const CGFloat kSpaceBetweenDotCenters = 22.0;
const CGFloat kDotContainerY = 8.0;

@implementation MIHSliderDotsControl

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _normalDotImage = [aDecoder decodeObjectForKey:@"_normalDotImage"];
        _highlightedDotImage = [aDecoder decodeObjectForKey:@"_highlightedDotImage"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_normalDotImage forKey:@"_normalDotImage"];
    [aCoder encodeObject:_highlightedDotImage forKey:@"_highlightedDotImage"];
    [super encodeWithCoder:aCoder];
}

- (void)setDotsCount:(NSUInteger)dotsCount
{
    _dotsCount = dotsCount;
    
    NSArray *subviewsToRemove = [NSArray arrayWithArray:self.subviews];
    [subviewsToRemove enumerateObjectsUsingBlock:^(NSView *subview, NSUInteger index, BOOL *stop) {
        [subview removeFromSuperview];
    }];
    
    for (NSUInteger currentDotIndex = 0; currentDotIndex < _dotsCount; currentDotIndex++) {
        NSButton *dotView = [[NSButton alloc] initWithFrame:NSMakeRect(currentDotIndex * kSpaceBetweenDotCenters, 0.0, kDotImageSize, kDotImageSize)];
        [dotView setImage:(_indexOfHighlightedDot == currentDotIndex ? self.highlightedDotImage : self.normalDotImage)];
        [dotView setAlternateImage:[dotView image]];
        [dotView setButtonType:NSMomentaryChangeButton];
        [dotView setBordered:NO];
        [dotView setTag:currentDotIndex];
        [dotView setTarget:self.sliderView];
        [dotView setAction:@selector(_dotViewSelected:)];
        
        [self addSubview:dotView];
    }
    
    self.frame = NSMakeRect((self.sliderView.bounds.size.width - (dotsCount * kSpaceBetweenDotCenters + kDotImageSize) + kSpaceBetweenDotCenters) / 2, kDotContainerY, dotsCount * kSpaceBetweenDotCenters + kDotImageSize, kDotImageSize);
}

- (void)setIndexOfHighlightedDot:(NSUInteger)indexOfHighlightedDot
{
    _indexOfHighlightedDot = indexOfHighlightedDot;
    
    [self.subviews enumerateObjectsUsingBlock:^(NSView *subview, NSUInteger index, BOOL *stop) {
        if ([subview isKindOfClass:[NSButton class]]) {
            [(NSButton *)subview setImage:(indexOfHighlightedDot == subview.tag ? self.highlightedDotImage : self.normalDotImage)];
        }
    }];
}

@end
