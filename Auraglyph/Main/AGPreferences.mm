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


void AGPreferences::setLastOpenedDocument(const AGFile &file)
{
    if(file.m_source == AGFile::USER)
    {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithSTLString:file.m_filename]
                                                  forKey:AGPreferencesLastOpenedDocument];
    }
}

AGFile AGPreferences::lastOpenedDocument()
{
    std::string filename;
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:AGPreferencesLastOpenedDocument];
    if(value != nil)
        filename = [value stlString];
    else
        filename = std::string("");
    return AGFile::UserFile(filename);
}
