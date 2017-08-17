//
//  AGControlMapNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGControlNode.h"

//------------------------------------------------------------------------------
// ### AGControlMapNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMapNode

class AGControlMapNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_INPUT,
        PARAM_MIN_IN,
        PARAM_MAX_IN,
        PARAM_MIN_OUT,
        PARAM_MAX_OUT,
        PARAM_POWER,
        PARAM_QUANTIZE,
        PARAM_OUTPUT
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlMapNode>
    {
    public:
        string _type() const override { return "Map"; };
        string _name() const override { return "Map"; };
        string _description() const override { return "Map value in an input range to an output range."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", 0, -AGFloat_Max, AGFloat_Max, AGPortInfo::LIN, .doc = "Input value to map." },
            };
        }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_MIN_IN, "min in", 0, -AGFloat_Max, AGFloat_Max, AGPortInfo::EXP, .doc = "Minimum input value." },
                { PARAM_MAX_IN, "max in", 0, -AGFloat_Max, AGFloat_Max, AGPortInfo::EXP, .doc = "Maximum input value." },
                { PARAM_MIN_OUT, "min out", 0, -AGFloat_Max, AGFloat_Max, AGPortInfo::EXP, .doc = "Minimum output value." },
                { PARAM_MAX_OUT, "max out", 0, -AGFloat_Max, AGFloat_Max, AGPortInfo::EXP, .doc = "Maximum output value." },
                { PARAM_POWER, "power", 1, 0, AGFloat_Max, AGPortInfo::EXP, .doc = "Non-linear power scale factor." },
                { PARAM_QUANTIZE, "qntize", 0, 0, 1, AGPortInfo::LIN, .type = AGControl::TYPE_BIT, .doc = "Quantize output value to a whole integer." },
            };
        }
        
        vector<AGPortInfo> _outputPortInfo() const override {
            return {
                { PARAM_OUTPUT, "output", .doc = "" },
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 26;
            float radiusYL = 13;
            float radiusYR = 26;
            float f = 0.45;
            
            return vector<GLvertex3f>{
                // left branch
                { -radius, radiusYL, 0 }, { -radius*f, radiusYL, 0 },
                { -radius*f, radiusYL, 0 }, { -radius*f, -radiusYL, 0 },
                { -radius, -radiusYL, 0 }, { -radius*f, -radiusYL, 0 },
                // connecting line
                { -radius*f, 0, 0 }, { radius*f, 0, 0 },
                // right branch
                { radius, radiusYR, 0 }, { radius*f, radiusYR, 0 },
                { radius*f, radiusYR, 0 }, { radius*f, -radiusYR, 0 },
                { radius, -radiusYR, 0 }, { radius*f, -radiusYR, 0 },
            };
        }
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        float minIn = param(PARAM_MIN_IN);
        float maxIn = param(PARAM_MAX_IN);
        float minOut = param(PARAM_MIN_OUT);
        float maxOut = param(PARAM_MAX_OUT);
        float power = param(PARAM_POWER);
        bool quantize = param(PARAM_QUANTIZE);
        
        float valueIn = control.getFloat();
        float unit = (valueIn-minIn)/(maxIn-minIn);
        if(power != 1.0f)
            unit = powf(unit, power);;
        float valueOut = minOut+(unit*(maxOut-maxIn));
        if(quantize)
            pushControl(0, AGControl((int)roundf(valueOut)));
        else
            pushControl(0, AGControl(valueOut));
    }
    
private:
    
    friend class AGControlGestureNodeEditor;
};

