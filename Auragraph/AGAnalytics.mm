//
//  AGAnalytics.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGAnalytics.h"

#import "GAI.h"
#import "GAIFields.h"
#import "GAIDictionaryBuilder.h"
#import "NSString+STLString.h"


#ifdef AG_USER_TEST_1
#define GA_TRACKING_ID @"***REMOVED***"
#else
#define GA_TRACKING_ID @"***REMOVED***"
#endif // AG_USER_TEST_1


#define VERBOSE_LOGGING (0)

#if TARGET_OS_SIMULATOR
#define DISABLE_ANALYTICS (1)
#else
#define DISABLE_ANALYTICS (0)
#endif // TARGET_OS_SIMULATOR


class AGGoogleAnalytics : public AGAnalytics
{
public:
    AGGoogleAnalytics()
    {
#if !DISABLE_ANALYTICS
        // set up Google Analytics
        // Initialize the default tracker. After initialization, [GAI sharedInstance].defaultTracker
        // returns this same tracker.
        (void) [[GAI sharedInstance] trackerWithTrackingId:GA_TRACKING_ID];
        
        // Provide unhandled exceptions reports.
#if !DEBUG || VERBOSE_LOGGING
        GAI *gai = [GAI sharedInstance];
#if !DEBUG
        gai.trackUncaughtExceptions = YES;
#endif
#if VERBOSE_LOGGING
        gai.logger.logLevel = kGAILogLevelVerbose;  // remove before app release
#endif // VERBOSE_LOGGING
#endif
        
#endif // !DISABLE_ANALYTICS
    }
    
    ~AGGoogleAnalytics()
    {
        
    }
    
    void eventAppLaunch() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"General"
                                                                action:@"AppLaunch"
                                                                 label:@""
                                                                 value:@1] build]];
    }
    
    void eventNodeMode() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"UI"
                                                                action:@"NodeTool"
                                                                 label:@""
                                                                 value:@1] build]];
    }
    
    void eventFreedrawMode() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"UI"
                                                                action:@"FreedrawTool"
                                                                 label:@""
                                                                 value:@1] build]];
    }
    
    void eventSave() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"UI"
                                                                action:@"Save"
                                                                 label:@""
                                                                 value:@1] build]];
    }
    
    void eventTrainer() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"UI"
                                                                action:@"Trainer"
                                                                 label:@""
                                                                 value:@1] build]];
    }
    
    void eventDeleteNode(const std::string &type) override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"UI"
                                                                action:@"DeleteNode"
                                                                 label:[NSString stringWithSTLString:type]
                                                                 value:@1] build]];
    }
    
    void eventDrawNodeCircle() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"DrawNodeCircle"
                                                                 label:@""
                                                                 value:@1] build]];
    }

    void eventDrawNodeSquare() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"DrawNodeSquare"
                                                                 label:@""
                                                                 value:@1] build]];
    }

    void eventDrawNodeTriangleUp() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"DrawNodeTriangleUp"
                                                                 label:@""
                                                                 value:@1] build]];
    }

    void eventDrawNodeTriangleDown() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"DrawNodeTriangleDown"
                                                                 label:@""
                                                                 value:@1] build]];
    }

    void eventDrawNodeUnrecognized() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"DrawNodeUnrecognized"
                                                                 label:@""
                                                                 value:@1] build]];
    }

    
    void eventCreateNode(AGDocument::Node::Class _class, const std::string &type) override
    {
        NSString *action = nil;
        NSString *label = nil;
        switch(_class)
        {
            case AGDocument::Node::AUDIO:
                action = @"CreateNodeAudio";
                label = [NSString stringWithFormat:@"Audio:%s", type.c_str()];
                break;
            case AGDocument::Node::CONTROL:
                action = @"CreateNodeControl";
                label = [NSString stringWithFormat:@"Control:%s", type.c_str()];
                break;
            case AGDocument::Node::INPUT:
                action = @"CreateNodeInput";
                label = [NSString stringWithFormat:@"Input:%s", type.c_str()];
                break;
            case AGDocument::Node::OUTPUT:
                action = @"CreateNodeOuptut";
                label = [NSString stringWithFormat:@"Output:%s", type.c_str()];
                break;
        }
        
        assert(action != nil && label != nil);
        
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:action
                                                                 label:[NSString stringWithSTLString:type]
                                                                 value:@1] build]];
    }

    void eventDrawFreedraw() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"DrawFreedraw"
                                                                 label:@""
                                                                 value:@1] build]];
    }
    
    void eventMoveNode(const std::string &type) override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"MoveNode"
                                                                 label:[NSString stringWithSTLString:type]
                                                                 value:@1] build]];
    }
    
    void eventConnectNode(const std::string &srcType, const std::string &dstType) override
    {
        std::string label = srcType + "->" + dstType;
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"ConnectNodes"
                                                                 label:[NSString stringWithSTLString:label]
                                                                 value:@1] build]];
    }
    
    void eventOpenNodeEditor(const std::string &type) override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"OpenNodeEditor"
                                                                 label:[NSString stringWithSTLString:type]
                                                                 value:@1] build]];
    }

    void eventEditNodeParamSlider(const std::string &type, const std::string &param) override
    {
        std::string label = type + ":" + param;
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"EditNodeParamSlider"
                                                                 label:[NSString stringWithSTLString:label]
                                                                 value:@1] build]];
    }

    void eventEditNodeParamDrawOpen(const std::string &type, const std::string &param) override
    {
        std::string label = type + ":" + param;
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"EditNodeParamDrawOpen"
                                                                 label:[NSString stringWithSTLString:label]
                                                                 value:@1] build]];
    }

    void eventEditNodeParamDrawAccept(const std::string &type, const std::string &param) override
    {
        std::string label = type + ":" + param;
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"EditNodeParamDrawAccept"
                                                                 label:[NSString stringWithSTLString:label]
                                                                 value:@1] build]];
    }

    void eventEditNodeParamDrawDiscard(const std::string &type, const std::string &param) override
    {
        std::string label = type + ":" + param;
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"EditNodeParamDrawDiscard"
                                                                 label:[NSString stringWithSTLString:label]
                                                                 value:@1] build]];
    }

    
    void eventDrawNumeral(int num) override
    {
        NSString *action = [NSString stringWithFormat:@"DrawNumeral%i", num];
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:action
                                                                 label:@""
                                                                 value:@1] build]];
    }

    void eventDrawNumeralUnrecognized() override
    {
        [tracker() send:[[GAIDictionaryBuilder createEventWithCategory:@"Interaction"
                                                                action:@"DrawNumeralUnrecognized"
                                                                 label:@""
                                                                 value:@1] build]];
    }

    
private:
    id<GAITracker> tracker()
    {
#if DISABLE_ANALYTICS
        return nil;
#else
        return [GAI sharedInstance].defaultTracker;
#endif
    }
};


AGAnalytics &AGAnalytics::instance()
{
    static AGGoogleAnalytics s_analytics;
    
    return s_analytics;
}

