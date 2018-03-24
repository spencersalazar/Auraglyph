//
//  AGPreferences.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 11/21/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGPreferences.h"
#include "NSString+STLString.h"

NSString *const AGPreferencesLastOpenedDocument = @"AGPreferencesLastOpenedDocument";

//------------------------------------------------------------------------------
// ### AGPreferences ###
//------------------------------------------------------------------------------
#pragma mark - AGPreferences

AGPreferences &AGPreferences::instance()
{
    static AGPreferences s_instance;
    return s_instance;
}

AGPreferences::AGPreferences()
{
    // set defaults as needed
}


void AGPreferences::setLastOpenedDocument(const std::string &filename)
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithSTLString:filename]
                                              forKey:AGPreferencesLastOpenedDocument];
}

std::string AGPreferences::lastOpenedDocument()
{
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:AGPreferencesLastOpenedDocument];
    if(value != nil)
        return [value stlString];
    else
        return std::string("");
}
