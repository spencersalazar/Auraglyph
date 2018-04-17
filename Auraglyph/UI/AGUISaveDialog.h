//
//  AGUISaveLoadDialog.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/15/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGUserInterface.h"
#include "AGDocument.h"

//------------------------------------------------------------------------------
// ### AGUISaveDialog ###
//------------------------------------------------------------------------------
#pragma mark - AGUISaveDialog

class AGUISaveDialog : public AGInteractiveObject
{
public:
    static AGUISaveDialog *save(const AGDocument &doc, const GLvertex3f &pos = GLvertex3f(0, 0, 0));
    
    virtual ~AGUISaveDialog() { }
    
    virtual void onSave(const std::function<void (const std::string &file, const vector<vector<GLvertex2f>> &name)> &) = 0;
};

