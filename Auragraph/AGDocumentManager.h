//
//  AGDocumentManager.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/17/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGDocumentManager_h
#define AGDocumentManager_h

#include "Geometry.h"

#include <string>
#include <vector>
#include <list>


class AGDocument;

struct AGDocumentListing
{
    std::string filename;
    std::vector<std::vector<GLvertex2f>> name;
};


class AGDocumentManager
{
public:
    
    static AGDocumentManager &instance();
    
    std::string save(const std::vector<std::vector<GLvertex2f>> &, const AGDocument &);
    void update(const std::string &, const AGDocument &);
    AGDocument load(const std::string &);
    const std::vector<AGDocumentListing> &list();
    
private:
    
    std::vector<AGDocumentListing> *m_list;
    
    void _loadList();
    void _saveList();
};


#endif /* AGDocumentManager_hpp */
