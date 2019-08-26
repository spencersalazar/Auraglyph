//
//  AGSettings.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 11/21/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGSettings.h"
#include "NSString+STLString.h"
#include <UIKit/UIKit.h>

/* Settings */
NSString* const AGSettingsFirstLaunchSettings = @"AGFirstLaunch";
NSString *const AGSettingsLastOpenedDocument = @"AGSettingsLastOpenedDocument";

/* Launch arguments */
NSString* const AGSettingsLaunchTutorialArgument = @"-AGLaunchTutorial";

/* Defaults */
NSDictionary* const AGSettingsDefaults = @{ AGSettingsFirstLaunchSettings: @YES, };


//------------------------------------------------------------------------------
// ### AGSettings ###
//------------------------------------------------------------------------------
#pragma mark - AGSettings

AGSettings &AGSettings::instance()
{
    static AGSettings s_instance;
    return s_instance;
}

AGSettings::AGSettings()
{
    m_defaults = [NSUserDefaults standardUserDefaults];
    [m_defaults registerDefaults:AGSettingsDefaults];
    
    m_firstLaunch = [m_defaults boolForKey:AGSettingsFirstLaunchSettings];
    [m_defaults setBool:NO forKey:AGSettingsFirstLaunchSettings];
}


void AGSettings::setLastOpenedDocument(const AGFile &file)
{
    if(file.m_source == AGFile::USER) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithSTLString:file.m_filename]
                                                  forKey:AGSettingsLastOpenedDocument];
    }
}

AGFile AGSettings::lastOpenedDocument()
{
    std::string filename;
    
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:AGSettingsLastOpenedDocument];
    if(value != nil) {
        filename = [value stlString];
    } else {
        filename = std::string("");
    }
    
    return AGFile::UserFile(filename);
}

bool AGSettings::showTutorialOnLaunch()
{
    NSProcessInfo* processInfo = [NSProcessInfo processInfo];
    if([processInfo.arguments containsObject:AGSettingsLaunchTutorialArgument]) {
        return true;
    }
    
    if(m_firstLaunch) {
        return true;
    }
    
    return false;
}
