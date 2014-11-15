//
//  AGDef.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/18/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_AGDef_h
#define Auragraph_AGDef_h


#define SAFE_DELETE(x) if( x!=NULL ) { delete x; x = NULL; }
#define SAFE_DELETE_ARRAY(x) if( x!=NULL ) { delete[] x; x = NULL; }

#define G_RATIO ((float) 1.61803398875)

#define AGBlock_copy(b) b
#define AGBlock_release(b)

#endif
