//
//  AGGenericShader.mm
//  Auragraph
//
//  Created by Spencer Salazar on 8/16/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGGenericShader.h"
#import "ShaderHelper.h"


static AGGenericShader *g_shader = NULL;

const AGGenericShader &AGGenericShader::instance()
{
    if(g_shader ==  NULL) g_shader = new AGGenericShader();
    
    return *g_shader;
}

void AGGenericShader::useProgram() const
{
    glUseProgram(m_program);
}

void AGGenericShader::setMVPMatrix(const GLKMatrix4 &mvpm) const
{
    glUniformMatrix4fv(m_uniformMVPMatrix, 1, 0, mvpm.m);
}

void AGGenericShader::setNormalMatrix(const GLKMatrix3 &nm) const
{
    glUniformMatrix3fv(m_uniformNormalMatrix, 1, 0, nm.m);
}

AGGenericShader::AGGenericShader()
{
    m_program = [ShaderHelper createProgram:@"Shader"
                             withAttributes:SHADERHELPER_ATTR_POSITION | SHADERHELPER_ATTR_NORMAL | SHADERHELPER_ATTR_COLOR];
    m_uniformMVPMatrix = glGetUniformLocation(m_program, "modelViewProjectionMatrix");
    m_uniformNormalMatrix = glGetUniformLocation(m_program, "normalMatrix");
}

