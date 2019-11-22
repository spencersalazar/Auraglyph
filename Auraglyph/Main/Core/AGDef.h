//
//  AGDef.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/18/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_AGDef_h
#define Auragraph_AGDef_h

#include <stddef.h> // for NULL
#include <stdio.h> // for fprintf/stderr

#define SAFE_DELETE(x) if( x!=NULL ) { delete x; x = NULL; }
#define SAFE_DELETE_ARRAY(x) if( x!=NULL ) { delete[] x; x = NULL; }

#define G_RATIO ((float) 1.61803398875)

#define AGBlock_copy(b) b
#define AGBlock_release(b)

#ifdef DEBUG
#define ENABLE_DEBUG_PRINT 1
#else 
#define ENABLE_DEBUG_PRINT 0
#endif 

#define dbgprint(...) do { if (ENABLE_DEBUG_PRINT) fprintf(stderr, ##__VA_ARGS__); } while (0)
#define dbgprint_off(...) do { if (0) fprintf(stderr, ##__VA_ARGS__); } while (0)

typedef long long sampletime;
#define AUDIO_BUFFER_MAX (1024)

#ifdef __OBJC__
#define FORWARD_DECLARE_OBJC_CLASS(cls) @class cls;
#else
#define FORWARD_DECLARE_OBJC_CLASS(cls) typedef void cls;
#endif // __OBJC__

#endif
