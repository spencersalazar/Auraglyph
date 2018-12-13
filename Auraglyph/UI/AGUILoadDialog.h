//
//  AGUILoadDialog.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/17/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGUserInterface.h"
#include "AGDocument.h"
#include "AGFileManager.h"

//------------------------------------------------------------------------------
// ### AGUILoadDialog ###
//------------------------------------------------------------------------------
#pragma mark - AGUILoadDialog

class AGUILoadDialog : public AGInteractiveObject
{
public:
    static AGUILoadDialog *load(const GLvertex3f &pos = GLvertex3f(0, 0, 0));
    static AGUILoadDialog *loadExample(const GLvertex3f &pos = GLvertex3f(0, 0, 0));
    
    virtual ~AGUILoadDialog() { }
    
    /** Called when the given document is selected for loading */
    virtual void onLoad(const std::function<void (const AGFile &file, AGDocument &doc)> &onLoad) { m_onLoad = onLoad; }
    /** Called when the utility function (e.g. delete) is called for the given file */
    virtual void onUtility(const std::function<void (const AGFile &file)> &onUtility) { m_onUtility = onUtility; }
    
private:
    std::function<void (const AGFile &file, AGDocument &doc)> m_onLoad = [](const AGFile &, AGDocument &) {};
    std::function<void (const AGFile &file)> m_onUtility = [](const AGFile &) {};
};


