//
//  AGAnalytics.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGAnalytics_h
#define AGAnalytics_h

#include <string>
#include "AGDocument.h"

class AGAnalytics
{
public:
    static AGAnalytics &instance();
    
    virtual ~AGAnalytics() { }
    
    /* event logging */
    virtual void eventAppLaunch() = 0;
    
    virtual void eventNodeMode() = 0;
    virtual void eventFreedrawMode() = 0;
    virtual void eventSave() = 0;
    virtual void eventTrainer() = 0;
    virtual void eventDeleteNode(const std::string &type) = 0;
    
    virtual void eventDrawNodeCircle() = 0;
    virtual void eventDrawNodeSquare() = 0;
    virtual void eventDrawNodeTriangleUp() = 0;
    virtual void eventDrawNodeTriangleDown() = 0;
    virtual void eventDrawNodeUnrecognized() = 0;
    
    virtual void eventCreateNode(AGDocument::Node::Class _class, const std::string &type) = 0;
    
    virtual void eventDrawFreedraw() = 0;
    
    virtual void eventMoveNode(const std::string &type) = 0;
    virtual void eventConnectNode(const std::string &srcType, const std::string &dstType) = 0;
    virtual void eventOpenNodeEditor(const std::string &type) = 0;
    virtual void eventEditNodeParamSlider(const std::string &type, const std::string &param) = 0;
    virtual void eventEditNodeParamDrawOpen(const std::string &type, const std::string &param) = 0;
    virtual void eventEditNodeParamDrawAccept(const std::string &type, const std::string &param) = 0;
    virtual void eventEditNodeParamDrawDiscard(const std::string &type, const std::string &param) = 0;
    
    virtual void eventDrawNumeral(int num) = 0;
    virtual void eventDrawNumeralUnrecognized() = 0;
};

#endif /* AGAnalytics_hpp */
