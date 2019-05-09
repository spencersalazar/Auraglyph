//
//  Var.h
//  Auraglyph
//
//  Created by Spencer Salazar on 1/4/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "Geometry.h"

#include <string>
#include <functional>

class Variant
{
public:
    
    enum Type { NONE = 0, INT, FLOAT, STRING, VERTEX2, VERTEX3, };
    
    Variant() : m_type(NONE), m_dynamic(false) { }
    Variant(int i) : m_type(INT), m_dynamic(false), m_i(i), m_f(i) { }
    Variant(float f) : m_type(FLOAT), m_dynamic(false), m_f(f) { }
    Variant(double f) : m_type(FLOAT), m_dynamic(false), m_f((float)f) { }
    Variant(const std::string &str) : m_type(STRING), m_dynamic(false), m_str(str) { }
    Variant(const char *str) : m_type(STRING), m_dynamic(false), m_str(std::string(str)) { }
    Variant(const GLvertex2f &v2) : m_type(VERTEX2), m_dynamic(false), m_v2(v2) { }
    Variant(const GLvertex3f &v3) : m_type(VERTEX3), m_dynamic(false), m_v3(v3) { }
    
    Variant(const std::function<int ()> &ifun) : m_type(INT), m_dynamic(true), m_ifun(ifun) { }
    Variant(const std::function<float ()> &ffun) : m_type(FLOAT), m_dynamic(true), m_ffun(ffun) { }
    Variant(const std::function<std::string ()> &strfun) : m_type(STRING), m_dynamic(true), m_strfun(strfun) { }
    Variant(const std::function<GLvertex2f ()> &v2fun) : m_type(VERTEX2), m_dynamic(true), m_v2fun(v2fun) { }
    Variant(const std::function<GLvertex3f ()> &v3fun) : m_type(VERTEX3), m_dynamic(true), m_v3fun(v3fun) { }
    
    Type getType() const { return m_type; }
    
    int getInt() const { return !m_dynamic ? m_i : m_ifun();  }
    float getFloat() const { return !m_dynamic ? m_f : m_ffun(); }
    std::string getString() const { return !m_dynamic ? m_str : m_strfun(); }
    GLvertex2f getVertex2() const { return !m_dynamic ? m_v2 : m_v2fun(); }
    GLvertex3f getVertex3() const { return !m_dynamic ? m_v3 : m_v3fun(); }
    
    operator int() const { return getInt(); }
    operator float() const { return getFloat(); }
    operator std::string() const { return getString(); }
    operator GLvertex2f() const { return getVertex2(); }
    operator GLvertex3f() const { return getVertex3(); }
    
private:
    
    int m_i = 0;
    float m_f = 0;
    std::string m_str;
    GLvertex2f m_v2;
    GLvertex3f m_v3;
    
    std::function<int ()> m_ifun;
    std::function<float ()> m_ffun;
    std::function<std::string ()> m_strfun;
    std::function<GLvertex2f ()> m_v2fun;
    std::function<GLvertex3f ()> m_v3fun;
    
    Type m_type = NONE;
    bool m_dynamic = false;
};

template<typename T>
bool operator==(const Variant& a, const T &b)
{
    return (T)a == b;
}

template<typename T>
bool operator!=(const Variant& a, const T &b)
{
    return (T)a != b;
}
