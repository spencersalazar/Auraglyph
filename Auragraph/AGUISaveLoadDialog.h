//
//  AGUISaveLoadDialog.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/15/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGUISaveLoadDialog_h
#define AGUISaveLoadDialog_h

#include "AGUserInterface.h"
#include "AGDocument.h"

class AGUISaveDialog : public AGInteractiveObject
{
public:
    static AGUISaveDialog *save(const AGDocument &doc, const GLvertex3f &pos = GLvertex3f(0, 0, 0));
    
    virtual ~AGUISaveDialog() { }
    
    virtual void onSave(const std::function<void (const std::string &file)> &) = 0;
};

class AGUILoadDialog : public AGInteractiveObject
{
public:
    static AGUILoadDialog *load(const GLvertex3f &pos = GLvertex3f(0, 0, 0));
    
    virtual ~AGUILoadDialog() { }
    
    virtual void onLoad(const std::function<void (const std::string &file, AGDocument &doc)> &) = 0;
};

#endif /* AGUISaveLoadDialog_hpp */
