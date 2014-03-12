//
//  AGGenericShader.mm
//  Auragraph
//
//  Created by Spencer Salazar on 8/16/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGGenericShader.h"
#import "ShaderHelper.h"
#import "AGAudioNode.h"


static AGGenericShader *g_shader = NULL;

AGGenericShader &AGGenericShader::instance()
{
    if(g_shader ==  NULL) g_shader = new AGGenericShader();
    
    return *g_shader;
}

AGGenericShader::AGGenericShader(NSString *name, EnableAttributes attributes)
{
    m_program = [ShaderHelper createProgram:name
                             withAttributes:attributes];
    m_uniformMVPMatrix = glGetUniformLocation(m_program, "modelViewProjectionMatrix");
    m_uniformNormalMatrix = glGetUniformLocation(m_program, "normalMatrix");
    
    m_proj = GLKMatrix4Identity;
    m_mv = GLKMatrix4Identity;
}

AGGenericShader::AGGenericShader(NSString *name, const map<int, string> &attributeMap)
{
    m_program = [ShaderHelper createProgram:name
                           withAttributeMap:attributeMap];
    m_uniformMVPMatrix = glGetUniformLocation(m_program, "modelViewProjectionMatrix");
    m_uniformNormalMatrix = glGetUniformLocation(m_program, "normalMatrix");
    
    m_proj = GLKMatrix4Identity;
    m_mv = GLKMatrix4Identity;
}

void AGGenericShader::useProgram()
{
    glUseProgram(m_program);
}

void AGGenericShader::setProjectionMatrix(const GLKMatrix4 &p)
{
    m_proj = p;
    glUniformMatrix4fv(m_uniformMVPMatrix, 1, 0, GLKMatrix4Multiply(m_proj, m_mv).m);
}

void AGGenericShader::setModelViewMatrix(const GLKMatrix4 &mv)
{
    m_mv = mv;
    glUniformMatrix4fv(m_uniformMVPMatrix, 1, 0, GLKMatrix4Multiply(m_proj, m_mv).m);
}

void AGGenericShader::setMVPMatrix(const GLKMatrix4 &mvpm)
{
    glUniformMatrix4fv(m_uniformMVPMatrix, 1, 0, mvpm.m);
}

void AGGenericShader::setNormalMatrix(const GLKMatrix3 &nm)
{
    glUniformMatrix3fv(m_uniformNormalMatrix, 1, 0, nm.m);
}


static AGClipShader *g_clipShader = NULL;

AGClipShader &AGClipShader::instance()
{
    if(g_clipShader ==  NULL) g_clipShader = new AGClipShader();
    
    return *g_clipShader;
}

AGClipShader::AGClipShader() : AGGenericShader(@"Clip")
{
    m_uniformLocalMatrix = glGetUniformLocation(m_program, "localMatrix");
    m_uniformClipOrigin = glGetUniformLocation(m_program, "clipOrigin");
    m_uniformClipSize = glGetUniformLocation(m_program, "clipSize");
}

void AGClipShader::setClip(const GLvertex2f &origin, const GLvertex2f &size)
{
    glUniform2f(m_uniformClipOrigin, origin.x, origin.y);
    glUniform2f(m_uniformClipSize, size.x, size.y);
}

void AGClipShader::setLocalMatrix(const GLKMatrix4 &l)
{
    glUniformMatrix4fv(m_uniformLocalMatrix, 1, 0, l.m);
}


static AGTextureShader *g_textureShader = NULL;

AGTextureShader &AGTextureShader::instance()
{
    if(g_textureShader ==  NULL) g_textureShader = new AGTextureShader();
    
    return *g_textureShader;
}

AGTextureShader::AGTextureShader() : AGGenericShader(@"Texture", SHADERHELPER_PNTC)
{
    m_uniformTex = glGetUniformLocation(m_program, "tex");
}

void AGTextureShader::useProgram()
{
    AGGenericShader::useProgram();
    
    // default: use texture 0
    glUniform1i(m_uniformTex, 0);
}


const GLint AGWaveformShader::s_attribPositionX = GLKVertexAttribTexCoord1+1;
const GLint AGWaveformShader::s_attribPositionY = GLKVertexAttribTexCoord1+2;

static AGWaveformShader *g_waveformShader = NULL;
static map<int, string> *g_waveformShaderAttrib = NULL;

AGWaveformShader &AGWaveformShader::instance()
{
    if(g_waveformShader ==  NULL)
    {
        g_waveformShaderAttrib = new map<int, string>;
        (*g_waveformShaderAttrib)[GLKVertexAttribNormal] = "normal";
        (*g_waveformShaderAttrib)[GLKVertexAttribColor] = "color";
        (*g_waveformShaderAttrib)[s_attribPositionX] = "positionX";
        (*g_waveformShaderAttrib)[s_attribPositionY] = "positionY";

        g_waveformShader = new AGWaveformShader();
    }
    
    return *g_waveformShader;
}

AGWaveformShader::AGWaveformShader() :
AGGenericShader(@"Waveform", *g_waveformShaderAttrib)
{
    m_uniformPositionZ = glGetUniformLocation(m_program, "positionZ");

    int bufSize = AGAudioNode::bufferSize();
    m_xBuffer = new GLfloat[bufSize];
    for(int i = 0; i < bufSize; i++)
    {
        m_xBuffer[i] = ((float) i)/((float) (bufSize-1));
    }
}

void AGWaveformShader::useProgram()
{
    AGGenericShader::useProgram();
    
    glVertexAttribPointer(s_attribPositionX, 1, GL_FLOAT, GL_FALSE, 0, m_xBuffer);
    glEnableVertexAttribArray(s_attribPositionX);
}

void AGWaveformShader::setZ(const GLfloat z)
{
    glUniform1f(m_uniformPositionZ, z);
}



