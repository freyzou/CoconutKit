//
//  HLSAnimationStep.m
//  nut
//
//  Created by Samuel Défago on 8/10/10.
//  Copyright 2010 Hortis. All rights reserved.
//

#import "HLSAnimationStep.h"

#import "HLSFloat.h"
#import "HLSLogger.h"

// Default values as given by Apple UIView documentation
static const double kAnimationStepDefaultDuration = 0.2;
static const UIViewAnimationCurve kAnimationStepDefaultCurve = UIViewAnimationCurveEaseInOut;

@interface HLSAnimationStep ()

@property (nonatomic, retain) NSMutableArray *viewKeys;
@property (nonatomic, retain) NSMutableDictionary *viewToViewAnimationStepMap;

@end

@implementation HLSAnimationStep

#pragma mark Convenience methods

+ (HLSAnimationStep *)animationStep
{
    return [[[[self class] alloc] init] autorelease];
}

+ (HLSAnimationStep *)animationStepAnimatingView:(UIView *)view 
                                       fromFrame:(CGRect)fromFrame 
                                         toFrame:(CGRect)toFrame
{
    return [HLSAnimationStep animationStepAnimatingView:view
                                              fromFrame:fromFrame
                                                toFrame:toFrame
                                     withAlphaVariation:0.f];
}

+ (HLSAnimationStep *)animationStepAnimatingView:(UIView *)view 
                                       fromFrame:(CGRect)fromFrame 
                                         toFrame:(CGRect)toFrame
                              withAlphaVariation:(CGFloat)alphaVariation
{
    HLSAnimationStep *animationStep = [HLSAnimationStep animationStep];
    HLSViewAnimationStep *viewAnimationStep = [HLSViewAnimationStep viewAnimationStepAnimatingViewFromFrame:fromFrame 
                                                                                                    toFrame:toFrame
                                                                                         withAlphaVariation:alphaVariation];
    [animationStep addViewAnimationStep:viewAnimationStep forView:view];
    return animationStep;
}

+ (HLSAnimationStep *)animationStepTranslatingView:(UIView *)view 
                                        withDeltaX:(CGFloat)deltaX
                                            deltaY:(CGFloat)deltaY
{
    return [HLSAnimationStep animationStepTranslatingView:view
                                               withDeltaX:deltaX
                                                   deltaY:deltaY
                                           alphaVariation:0.f];
}

+ (HLSAnimationStep *)animationStepTranslatingView:(UIView *)view 
                                        withDeltaX:(CGFloat)deltaX
                                            deltaY:(CGFloat)deltaY
                                    alphaVariation:(CGFloat)alphaVariation
{
    HLSAnimationStep *animationStep = [HLSAnimationStep animationStep];
    HLSViewAnimationStep *viewAnimationStep = [HLSViewAnimationStep viewAnimationStepTranslatingViewWithDeltaX:deltaX
                                                                                                        deltaY:deltaY
                                                                                                alphaVariation:alphaVariation];
    [animationStep addViewAnimationStep:viewAnimationStep forView:view];
    return animationStep;
}

+ (HLSAnimationStep *)viewAnimationChangingView:(UIView *)view
                             withAlphaVariation:(CGFloat)alphaVariation
{
    HLSAnimationStep *animationStep = [HLSAnimationStep animationStep];
    HLSViewAnimationStep *viewAnimationStep = [HLSViewAnimationStep viewAnimationStepUpdatingViewWithAlphaVariation:alphaVariation];
    [animationStep addViewAnimationStep:viewAnimationStep forView:view];
    return animationStep;
}

#pragma mark Object creation and destruction

- (id)init
{
    if (self = [super init]) {
        self.viewKeys = [NSMutableArray array];
        self.viewToViewAnimationStepMap = [NSMutableDictionary dictionary];
        
        // Default animation settings
        self.duration = kAnimationStepDefaultDuration;
        self.curve = kAnimationStepDefaultCurve;   
    }
    return self;
}

- (void)dealloc
{
    self.viewKeys = nil;
    self.viewToViewAnimationStepMap = nil;
    self.tag = nil;
    [super dealloc];
}

#pragma mark Accessors and mutators

- (void)addViewAnimationStep:(HLSViewAnimationStep *)viewAnimationStep forView:(UIView *)view
{   
    if (! viewAnimationStep) {
        logger_warn(@"View animation step is nil");
        return;
    }
    
    if (! view) {
        logger_warn(@"View is nil");
        return;
    }
    
    NSValue *viewKey = [NSValue valueWithPointer:view];
    [self.viewKeys addObject:viewKey];
    [self.viewToViewAnimationStepMap setObject:viewAnimationStep forKey:viewKey];
}

- (NSArray *)views
{
    NSMutableArray *views = [NSMutableArray array];
    for (NSValue *viewKey in self.viewKeys) {
        UIView *view = [viewKey pointerValue];
        [views addObject:view];
    }
    return views;
}

- (HLSViewAnimationStep *)viewAnimationStepForView:(UIView *)view
{
    if (! view) {
        return nil;
    }
    
    NSValue *viewKey = [NSValue valueWithPointer:view];
    return [self.viewToViewAnimationStepMap objectForKey:viewKey];
}

@synthesize viewKeys = m_viewKeys;

@synthesize viewToViewAnimationStepMap = m_viewToViewAnimationStepMap;

@synthesize duration = m_duration;

- (void)setDuration:(NSTimeInterval)duration
{
    // Sanitize input
    if (doublelt(duration, 0.)) {
        logger_warn(@"Duration must be non-negative. Fixed to 0");
        m_duration = 0.;
    }
    else {
        m_duration = duration;
    }
}

@synthesize curve = m_curve;

@synthesize tag = m_tag;

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; views: %@; viewAnimationSteps: %@; duration: %f; tag: %@>", 
            [self class],
            self,
            [self views],
            [self.viewToViewAnimationStepMap allValues],
            self.duration,
            self.tag];
}

@end
