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
        ParamValue() : type(INT), i(0), f(0) { }
        ParamValue(int _i) : type(INT), i(_i), f(0) { }
        ParamValue(float _f) : type(FLOAT), i(0), f(_f) { }
        ParamValue(const string &_s) : type(STRING), i(0), f(0), s(_s) { }
        ParamValue(const list<float> &_fa) : type(FLOAT_ARRAY), i(0), f(0), fa(_fa) { }
        
        enum Type { INT, FLOAT, STRING, FLOAT_ARRAY };
        Type type;
        int i;
        float f;
        string s;
        list<float> fa;
    };
    
    struct Connection
    {
        string uuid;
        string srcUuid;
        int srcPort;
        string dstUuid;
        int dstPort;
    };
    
    struct Node
    {
        enum Class { AUDIO, CONTROL, INPUT, OUTPUT, };
        Class _class;
        string type;
        string uuid;
        float x, y, z;
        list<Connection> inbound;
        list<Connection> outbound;
        map<string, ParamValue> params;
        
        void saveParam(const string &name, int p);
        void saveParam(const string &name, float p);
        void saveParam(const string &name, const vector<float> &p);

        void loadParam(const string &name, vector<float> &p) const;
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
    void load(const string &title);
    void loadFromPath(const string &path);
    void save() const;
    void saveTo(const string &title);
    void saveToPath(const string &path) const;
    
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
    
    static bool existsForTitle(const string &title);
    
private:
    string m_title;
    map<string, Node> m_nodes;
    map<string, Connection> m_connections;
    map<string, Freedraw> m_freedraws;
};


#endif /* defined(__Auragraph__AGDocument__) */
