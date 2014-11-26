//
//  AGDocument.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/21/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGDocument__
#define __Auragraph__AGDocument__

#include <string>
#include <map>
#include <vector>
#include <list>

using namespace std;

class AGAudioNode;
class AGControlNode;
class AGFreeDraw;
class AGConnection;

class AGDocument
{
public:
    struct ParamValue
    {
        enum { INT, FLOAT, STRING, FLOAT_ARRAY } type;
        int i;
        float f;
        string s;
        list<float> fa;
    };
    
    struct Node
    {
        enum Class { AUDIO, CONTROL, INPUT, OUTPUT, };
        Class _class;
        string type;
        string uuid;
        float x, y, z;
        map<string, ParamValue> params;
    };
    
    struct Connection
    {
        string uuid;
        string srcUuid;
        string dstUuid;
    };
    
    struct Freedraw
    {
        string uuid;
        float x, y, z;
        vector<float> points;
    };
    
    AGDocument();
    ~AGDocument();
    
    void create();
    void load(string title);
    void save();
    void saveTo(string title);
    
    void recreate(void (^createNode)(const Node &node),
                  void (^createConnection)(const Connection &connection),
                  void (^createFreedraw)(const Freedraw &freedraw));
    
    void addNode(const Node &node);
    void updateNode(const string &uuid, const Node &update);
    void removeNode(const string &uuid);
    
    void addConnection(const Connection &connection);
    void removeConnection(const string &uuid);
    
    void addFreedraw(const Freedraw &freedraw);
    void updateFreedraw(const string &uuid, const Freedraw &update);
    void removeFreedraw(const string &uuid);
    
//    static Node makeNode(AGAudioNode *);
//    static Node makeNode(AGControlNode *);
//    static Connection makeConnection(AGConnection *);
//    static Freedraw makeFreedraw(AGFreeDraw *);
    
private:
    string m_title;
    map<string, Node> m_nodes;
    map<string, Connection> m_connections;
    map<string, Freedraw> m_freedraws;
};


#endif /* defined(__Auragraph__AGDocument__) */
