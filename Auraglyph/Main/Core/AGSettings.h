//
//  AGSettings.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 11/21/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGDef.h"
#include <string>
#include "AGDocumentManager.h"


FORWARD_DECLARE_OBJC_CLASS(NSUserDefaults);


//------------------------------------------------------------------------------
// ### AGSettings ###
// Abstraction for preferences management
//------------------------------------------------------------------------------
#pragma mark - AGSettings

class AGSettings
{
public:
    static AGSettings &instance();
    
    AGSettings();
    
    void setLastOpenedDocument(const AGFile &file);
    AGFile lastOpenedDocument();
    
    bool showTutorialOnLaunch();
    
private:
    NSUserDefaults* m_defaults = nullptr;
    bool m_firstLaunch = false;
};
