//
//  TexFont.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "TexFont.h"

bool TexFont::s_init = false;
GLuint TexFont::s_program = 0;
GLuint TexFont::s_vertexArray = 0;
GLuint TexFont::s_vertexBuffer = 0;
GLuint TexFont::s_geoSize = 0;
GLgeoprimf *TexFont::s_geo = NULL;
