//
//  AGDocumentManager.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/17/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGDocumentManager_h
#define AGDocumentManager_h

#include "AGDocument.h"
#include "AGFileManager.h"

#include "Geometry.h"

#include <string>
#include <vector>
#include <list>


class AGDocumentManager
{
public:
    
    static AGDocumentManager &instance();
    
    struct DocumentListing
    {
        AGFile filename;
        std::vector<std::vector<GLvertex2f>> name;
    };
    
    AGFile save(const std::vector<std::vector<GLvertex2f>> &name, const AGDocument &doc);
    void update(const AGFile &file, const AGDocument &doc);
    AGDocument load(const AGFile &file);
    void remove(const AGFile &file);
    
    const std::vector<DocumentListing> &list();
    const std::vector<DocumentListing> &examplesList();

private:
    
    std::vector<DocumentListing> *m_list;
    std::vector<DocumentListing> *m_examplesList;

    void _loadList(bool force = false);
    std::vector<DocumentListing> *_doLoad(const std::string &dir, const std::string &listFile, AGFile::Source source);
    void _saveList();
};


#endif /* AGDocumentManager_hpp */
