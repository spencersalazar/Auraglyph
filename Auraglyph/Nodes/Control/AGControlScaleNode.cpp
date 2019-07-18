//
//  AGControlScaleNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGControlNode.h"

static const vector<vector<int>> g_scales = {
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, // chromatic
    { 0, 2, 4, 5, 7, 9, 11 }, // major
    { 0, 2, 3, 5, 7, 8, 10 }, // minor
};

static const vector<vector<int>> g_chords = {
    { }, // none
    { 0, 2, 4 }, // I (1st/3rd/5th scale degree)
    { 4, 6, 1 }, // V (5th/7th/2nd scale degree)
    { 4, 6, 1, 3 }, // V7 (5th/7th/2nd/4th scale degree)
    { 3, 5, 0 }, // IV (4th/6th/1st scale degree
    { 5, 0, 2 }, // VI (6th/1st/3rd scale degree
};

//------------------------------------------------------------------------------
// ### AGControlScaleNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlScaleNode

class AGControlScaleNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_INPUT,
        PARAM_ROOT,
        PARAM_SCALE,
        PARAM_CHORD,
        PARAM_OCTAVE,
        PARAM_QUANTIZE,
        PARAM_OUTPUT
    };
    
    enum Scale
    {
        SCALE_CHROMATIC = 0,
        SCALE_MAJOR = 1,
        SCALE_MINOR = 2,
    };
    
    enum Chord
    {
        CHORD_NONE = 0,
        CHORD_I,
        CHORD_V,
        CHORD_V7,
        CHORD_IV,
        CHORD_VI,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlScaleNode>
    {
    public:
        string _type() const override { return "Scale"; };
        string _name() const override { return "Scale"; };
        string _description() const override { return "Map value in an input range to an output range."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "degree", 0, -AGFloat_Max, AGFloat_Max, AGPortInfo::LIN, .doc = "Scale or chord degree." },
                { PARAM_ROOT, "root", 0, 0, 11, AGPortInfo::LIN, .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM,
                    .enumInfo = {
                        { 0, "C" },
                        { 1, "C#/Db" },
                        { 2, "D" },
                        { 3, "D#/Eb" },
                        { 4, "E" },
                        { 5, "F" },
                        { 6, "F#/Gb" },
                        { 7, "G" },
                        { 8, "G#/Ab" },
                        { 9, "A" },
                        { 10, "A#/Bb" },
                        { 11, "B" },
                    },
                    .doc = "Scale root."
                },
                { PARAM_SCALE, "scale", 0, 0, 2, AGPortInfo::LIN, .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM,
                    .enumInfo = {
                        { SCALE_CHROMATIC, "chrom" },
                        { SCALE_MAJOR, "major" },
                        { SCALE_MINOR, "minor" },
                    },
                    .doc = "Scale type."
                },
                { PARAM_CHORD, "chord", 0, 0, 5, AGPortInfo::LIN, .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM,
                    .enumInfo = {
                        { CHORD_NONE, "none" },
                        { CHORD_I, "I" },
                        { CHORD_V, "V" },
                        { CHORD_V7, "V7" },
                        { CHORD_IV, "IV" },
                        { CHORD_VI, "VI" },
                    },
                    .doc = "Scale chord."
                },
                { PARAM_OCTAVE, "octave", 0, -5, 5, AGPortInfo::LIN, .type = AGControl::TYPE_INT, .doc = "Scale octave." },
            };
        }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_ROOT, "root", 0, 0, 11, AGPortInfo::LIN, .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM,
                    .enumInfo = {
                        { 0, "C" },
                        { 1, "C#/Db" },
                        { 2, "D" },
                        { 3, "D#/Eb" },
                        { 4, "E" },
                        { 5, "F" },
                        { 6, "F#/Gb" },
                        { 7, "G" },
                        { 8, "G#/Ab" },
                        { 9, "A" },
                        { 10, "A#/Bb" },
                        { 11, "B" },
                    },
                    .doc = "Scale root."
                },
                { PARAM_SCALE, "scale", 0, 0, 2, AGPortInfo::LIN, .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM,
                    .enumInfo = {
                        { SCALE_CHROMATIC, "chromatic" },
                        { SCALE_MAJOR, "major" },
                        { SCALE_MINOR, "minor" },
                    },
                    .doc = "Scale type."
                },
                { PARAM_CHORD, "chord", 0, 0, 5, AGPortInfo::LIN, .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM,
                    .enumInfo = {
                        { CHORD_NONE, "none" },
                        { CHORD_I, "I" },
                        { CHORD_V, "V" },
                        { CHORD_V7, "V7" },
                        { CHORD_IV, "IV" },
                        { CHORD_VI, "VI" },
                    },
                    .doc = "Scale chord."
                },
                { PARAM_OCTAVE, "octave", 0, -5, 5, AGPortInfo::LIN, .type = AGControl::TYPE_INT, .doc = "Scale octave." },
                { PARAM_QUANTIZE, "qntize", 1, 0, 1, AGPortInfo::LIN, .type = AGControl::TYPE_BIT, .doc = "Quantize output value to a whole integer." },
            };
        }
        
        vector<AGPortInfo> _outputPortInfo() const override {
            return {
                { PARAM_OUTPUT, "output", .doc = "" },
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float r = 11; // radius of one hash
            float w = r*0.75, h = r;
            
            GLvertex2f c0 = GLvertex2f(-r*0.5,  r*1.5);
            GLvertex2f c1 = GLvertex2f( r*1.25,  0);
            GLvertex2f c2 = GLvertex2f(-r*0.5, -r*1.5);

            return {
                // #
                c0+GLvertex2f(-w, h/3), c0+GLvertex2f(w, h/3),
                c0+GLvertex2f(-w, -h/3), c0+GLvertex2f(w, -h/3),
                c0+GLvertex2f(-w/3+2, h), c0+GLvertex2f(-w/3-2, -h),
                c0+GLvertex2f(w/3+2, h), c0+GLvertex2f(w/3-2, -h),
                // #
                c1+GLvertex2f(-w, h/3), c1+GLvertex2f(w, h/3),
                c1+GLvertex2f(-w, -h/3), c1+GLvertex2f(w, -h/3),
                c1+GLvertex2f(-w/3+2, h), c1+GLvertex2f(-w/3-2, -h),
                c1+GLvertex2f(w/3+2, h), c1+GLvertex2f(w/3-2, -h),
                // #
                c2+GLvertex2f(-w, h/3), c2+GLvertex2f(w, h/3),
                c2+GLvertex2f(-w, -h/3), c2+GLvertex2f(w, -h/3),
                c2+GLvertex2f(-w/3+2, h), c2+GLvertex2f(-w/3-2, -h),
                c2+GLvertex2f(w/3+2, h), c2+GLvertex2f(w/3-2, -h),
            };
        }
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        int root = param(PARAM_ROOT);
        int scale_index = param(PARAM_SCALE);
        int chord_index = param(PARAM_CHORD);
        int octave = param(PARAM_OCTAVE);
        bool quantize = param(PARAM_QUANTIZE);
        
        root = 60+root+12*octave;
        
        if(control.type == AGControl::TYPE_INT || control.type == AGControl::TYPE_BIT)
        {
            int note_index = control.getInt();
            int note;
            
            if(chord_index == CHORD_NONE)
            {
                // pick directly from scale
                const vector<int> &scale = g_scales[scale_index];
                note = root+scale[note_index%scale.size()]+12*(note_index/scale.size());
            }
            else
            {
                // pick chord from scale
                const vector<int> &scale = g_scales[scale_index];
                const vector<int> &chord = g_chords[chord_index];
                note = root+scale[chord[note_index%chord.size()]]+12*(note_index/chord.size());
            }
            
            dbgprint_off("Scale: in: %i out: %i root: %i scale: %i chord: %i octave: %i\n",
               note_index, note, root, scale_index, chord_index, octave);

            pushControl(0, AGControl(note));
        }
        else
        {
            float valueIn = control.getFloat();
            float note;
            
            if(chord_index == CHORD_NONE)
            {
                // pick directly from scale
                const vector<int> &scale = g_scales[scale_index];
                
                if(quantize)
                {
                    int note_index = roundf(valueIn*scale.size());
                    
                    note = root +
                        scale[note_index%scale.size()] +
                        12*(note_index/scale.size());
                }
                else
                {
                    int note_index_low = floorf(valueIn*scale.size());
                    int note_index_high = ceilf(valueIn*scale.size());
                    float alpha = ceilf(valueIn)-valueIn;
                    
                    float note_low = root +
                        scale[note_index_low%scale.size()] +
                        12*(note_index_low/scale.size());
                    float note_high = root +
                        scale[note_index_high%scale.size()] +
                        12*(note_index_high/scale.size());
                    
                    dbgprint_off("idx_lo: %i idx_hi: %i alpha: %f\n", note_index_low, note_index_high, alpha);
                    
                    note = note_low*alpha + note_high*(1-alpha);
                }
                
            }
            else
            {
                // pick chord from scale
                const vector<int> &scale = g_scales[scale_index];
                const vector<int> &chord = g_chords[chord_index];
                
                if(quantize)
                {
                    int note_index = roundf(valueIn*scale.size());
                    
                    note = root +
                        scale[chord[note_index%chord.size()]] +
                        12*(note_index/chord.size());
                }
                else
                {
                    int note_index_low = floorf(valueIn*chord.size());
                    int note_index_high = ceilf(valueIn*chord.size());
                    float alpha = ceilf(valueIn)-valueIn;
                    
                    dbgprint_off("idx_lo: %i idx_hi: %i alpha: %f\n", note_index_low, note_index_high, alpha);
                    
                    float note_low = root +
                        scale[chord[note_index_low%chord.size()]] +
                        12*(note_index_low/chord.size());
                    float note_high = root +
                        scale[chord[note_index_high%chord.size()]] +
                        12*(note_index_high/chord.size());
                    
                    note = note_low*alpha + note_high*(1-alpha);
                }
            }
            
            dbgprint_off("Scale: in: %f out: %f root: %i scale: %i chord: %i octave: %i\n",
               valueIn, note, root, scale_index, chord_index, octave);
            
            if(quantize)
                pushControl(0, AGControl((int)note));
            else
                pushControl(0, AGControl(note));
        }
    }
    
private:
    
    friend class AGControlGestureNodeEditor;
};

