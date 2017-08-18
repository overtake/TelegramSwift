// MIHSliderView.h
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

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

/**
 `MIHSliderView` is a Core Animation based slider view to display a couple of views each after another. 
 Sliders are well known from web development were they are often used to display images or news. 
 With `MIHSliderView` it is possible to display any NSView inside a slider.
 
 For more information about MIHSliderView have a look at http://github.com/hohl/MIHSliderView
 */

typedef enum {
    MIHSliderTransitionFade,
    MIHSliderTransitionPushVertical,
    MIHSliderTransitionPushHorizontalFromLeft,
    MIHSliderTransitionPushHorizontalFromRight
} MIHSliderTransition;

@class MIHSliderDotsControl;

@interface MIHSliderView : NSView

///----------------------
/// @name Managing Slides
///----------------------

/**
 Array of all slides which the view displays. Use `addSlide:` and `removeSlide:` to manage the slides.
 */
@property (retain, readonly) NSArray *slides;

/**
 Adds a slide which should get displayed by the view.
 
 @param aSlide the slide to add at the last index
 */
- (void)addSlide:(NSView *)aSlide;

/**
 Removes the passed slide from the slider.
 
 @param aSlide the slide to remove from the slider
 */
- (void)removeSlide:(NSView *)aSlide;

///--------------------------------
/// @name Controlling Slider Output
///--------------------------------

/**
 Index of the current displayed slide.
To change the displayed slide use `displaySlideAtIndex:`.
 */
@property (assign, readonly) NSUInteger indexOfDisplayedSlide;

/**
 The slide which is displayed at the moment.
 To change the displayed slide use `displaySlideAtIndex:`.
 */
@property (retain, readonly) NSView *displayedSlide;

/**
 Displays a specific slide.
 
 @param aIndex the index of the slide which should get displayed.
 */
- (void)displaySlideAtIndex:(NSUInteger)aIndex;

///----------------------------------
/// @name Slide Transition Properties
///----------------------------------

/**
 Defines the animiation of the transition between the slides.
 */
@property (assign) MIHSliderTransition transitionStyle;

/**
 If this property is set to YES slides will automatically switch to the next slide after a short time.
 
 @discussion This property is set to YES per default.
 */
@property (assign) BOOL scheduledTransition;

/**
 If this property is set to YES slide 1 will get displayed after the last slide. Otherwise scheduled transitions will
 get stopped after the last transition.
 
 @discussion This property is set to YES per default.
 */
@property (assign) BOOL repeatingScheduledTransition;

/**
 Defines the number of seconds a slide should get displayed before transiting to the next slide.
 
 @discussion This property is set to 5.0 seconds per default.
 */
@property (assign) NSTimeInterval scheduledTransitionInterval;

/**
 Defines the duration of the transition animation.
 
 @discussion This property is set to 0.6 seconds per default.
 */
@property (assign) NSTimeInterval transitionAnimationDuration;

///-----------------------------
/// @name Look & Feel Properties
///-----------------------------

/**
 Container view for the dots. Via this class you are able to customize the look of the dots.
 */
@property (retain) MIHSliderDotsControl *dotsControl;

@end

@interface MIHSliderDotsControl : NSView

/**
 Image which is used to display a normal (not highligted) dot.
 */
@property (retain) NSImage *normalDotImage;

/**
 Image which is used to display a highlighted (means the current one) dot.
 */
@property (retain) NSImage *highlightedDotImage;

@end
