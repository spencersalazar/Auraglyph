//
//  AGDashboard.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/27/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGDashboard.h"
#include "AGViewController.h"
#include "AGMenu.h"
#include "AGUserInterface.h"
#include "AGStyle.h"
#include "GeoGenerator.h"
#include "AGAnalytics.h"
#include "AGUndoManager.h"
#include "AGDocumentationViewer.h"

#include <math.h>

AGDashboard::AGDashboard(AGViewController_ *viewController)
: m_viewController(viewController)
{
    float fileMenuWidth = 75;
    float fileMenuHeight = fileMenuWidth*0.4;
    m_fileMenu = new AGMenu(m_viewController->fixedCoordinateForScreenCoordinate(CGPointMake(10+fileMenuWidth/2,
                                                                                            10+fileMenuHeight/2)),
                           GLvertex2f(fileMenuWidth, fileMenuHeight));
    m_fileMenu->init();
    float iconRadius = fileMenuHeight/2*0.8f;
    m_fileMenu->setIcon((GLvertex3f[]) {
        { -iconRadius*0.7f, -iconRadius, 0 },
        { -iconRadius*0.7f,  iconRadius, 0 },
        {  iconRadius*0.7f,  iconRadius, 0 },
        {  iconRadius*0.7f, -iconRadius, 0 },
    }, 4, GL_LINE_LOOP);
    m_fileMenu->addMenuItem("New", [this](){
        dbgprint("New\n");
        m_viewController->createNew();
    });
    m_fileMenu->addMenuItem("Load", [this](){
        dbgprint("Load\n");
        //AGAnalytics::instance().event();
        // TODO: analytics
        m_viewController->load();
    });
    m_fileMenu->addMenuItem("Save", [this](){
        dbgprint("Save\n");
        AGAnalytics::instance().eventSave();
        m_viewController->save();
    });
    m_fileMenu->addMenuItem("Save As", [this](){
        dbgprint("Save As\n");
        m_viewController->saveAs();
    });
    addChild(m_fileMenu);
    
    m_editMenu = new AGMenu(m_viewController->fixedCoordinateForScreenCoordinate(CGPointMake(10+fileMenuWidth*1.2+fileMenuWidth/2,
                                                                                            10+fileMenuHeight/2)),
                           GLvertex2f(fileMenuWidth, fileMenuHeight));
    m_editMenu->init();
    float wrenchRadius = iconRadius*1.25;
    float wrenchRadius2 = iconRadius*0.62;
    float wrenchInnerRadius = wrenchRadius*0.3;
    float sqrt2 = M_SQRT2;
    float sqrt1_2 = M_SQRT1_2;
    float wrenchRot = -M_PI*0.3;
    vector<GLvertex3f> wrenchIcon = {
        rotateZ({ -wrenchRadius2/3, 0, 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3, wrenchRadius-wrenchInnerRadius*(1+sqrt2), 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3-wrenchInnerRadius/sqrt2, wrenchRadius-wrenchInnerRadius*(1+sqrt1_2), 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3-wrenchInnerRadius/sqrt2, wrenchRadius-wrenchInnerRadius*(sqrt1_2), 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3, wrenchRadius, 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3, wrenchRadius-wrenchInnerRadius, 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3, wrenchRadius-wrenchInnerRadius, 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3, wrenchRadius, 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3+wrenchInnerRadius/sqrt2, wrenchRadius-wrenchInnerRadius*(sqrt1_2), 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3+wrenchInnerRadius/sqrt2, wrenchRadius-wrenchInnerRadius*(1+sqrt1_2), 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3, wrenchRadius-wrenchInnerRadius*(1+sqrt2), 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3, 0, 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3, -wrenchRadius+wrenchInnerRadius*(1+sqrt2), 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3+wrenchInnerRadius/sqrt2, -wrenchRadius+wrenchInnerRadius*(1+sqrt1_2), 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3+wrenchInnerRadius/sqrt2, -wrenchRadius+wrenchInnerRadius*(sqrt1_2), 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3, -wrenchRadius, 0 }, wrenchRot),
        rotateZ({  wrenchRadius2/3, -wrenchRadius+wrenchInnerRadius, 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3, -wrenchRadius+wrenchInnerRadius, 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3, -wrenchRadius, 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3-wrenchInnerRadius/sqrt2, -wrenchRadius+wrenchInnerRadius*(sqrt1_2), 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3-wrenchInnerRadius/sqrt2, -wrenchRadius+wrenchInnerRadius*(1+sqrt1_2), 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3, -wrenchRadius+wrenchInnerRadius*(1+sqrt2), 0 }, wrenchRot),
        rotateZ({ -wrenchRadius2/3, 0, 0 }, wrenchRot),
    };
    m_editMenu->setIcon(wrenchIcon.data(), wrenchIcon.size(), GL_LINE_STRIP);
    m_editMenu->addMenuItem("Undo", [this](){
        dbgprint("Undo\n");
        // TODO: analytics
        AGUndoManager::instance().undoLast();
    });
    m_editMenu->addMenuItem("Redo", [this](){
        dbgprint("Redo\n");
        // TODO: analytics
        AGUndoManager::instance().redoLast();
    });
    addChild(m_editMenu);
    
    m_settingsMenu = new AGMenu(m_viewController->fixedCoordinateForScreenCoordinate(CGPointMake(10+fileMenuWidth*1.2*2+fileMenuWidth/2,
                                                                                                10+fileMenuHeight/2)),
                               GLvertex2f(fileMenuWidth, fileMenuHeight));
    m_settingsMenu->init();
    vector<GLvertex3f> gearIcon;
    int numTeeth = 7;
    float outerRadius = iconRadius;
    float innerRadius = iconRadius*0.8;
    float start = 0;
    for(int i = 0; i < numTeeth; i++)
    {
        float rot = (2*M_PI)/numTeeth;
        float pos = start+rot*i;
        gearIcon.push_back({ innerRadius*cosf(pos), innerRadius*sinf(pos), 0 });
        gearIcon.push_back({ outerRadius*cosf(pos), outerRadius*sinf(pos), 0 });
        gearIcon.push_back({ outerRadius*cosf(pos+rot/2), outerRadius*sinf(pos+rot/2), 0 });
        gearIcon.push_back({ innerRadius*cosf(pos+rot/2), innerRadius*sinf(pos+rot/2), 0 });
        gearIcon.push_back({ innerRadius*cosf(pos+rot), innerRadius*sinf(pos+rot), 0 });
    }
    m_settingsMenu->setIcon(gearIcon.data(), gearIcon.size(), GL_LINE_STRIP);
    m_settingsMenu->addMenuItem("Reference", [this](){
        dbgprint("Reference\n");
        // TODO: analytics
        AGDocumentationViewer::show();
    });
    m_settingsMenu->addMenuItem("Examples", [this](){
        dbgprint("Examples\n");
        // TODO: analytics
        m_viewController->loadExample();
    });
    m_settingsMenu->addMenuItem("Settings", [this](){
        dbgprint("Settings\n");
        // TODO: analytics
    });
    m_settingsMenu->addMenuItem("Trainer", [this](){
        dbgprint("Trainer\n");
        AGAnalytics::instance().eventTrainer();
        m_viewController->showTrainer();
    });
    m_settingsMenu->addMenuItem("About", [this](){
        dbgprint("About\n");
        // TODO: analytics
        m_viewController->showAbout();
    });
    addChild(m_settingsMenu);
    
    TexFont *font = AGStyle::standardFont96();

    float recordButtonWidth = font->width("  Save  ")*1.05;
    float recordButtonHeight = font->height()*1.05;
    m_recordButton = new AGUIButton("Record",
                                    m_viewController->fixedCoordinateForScreenCoordinate(CGPointMake(m_viewController->bounds().size.width-recordButtonWidth-20, 20+recordButtonHeight/2)),
                                    GLvertex2f(recordButtonWidth, recordButtonHeight));
    m_recordButton->init();
    m_recordButton->setRenderFixed(true);
    m_recordButton->setAction(^{
        // AGAnalytics::instance().eventTrainer();
        // TODO: analytics
        // flip toggle
        if((m_isRecording = !m_isRecording))
        {
            m_viewController->startRecording();
            m_recordButton->setTitle("Stop");
        }
        else
        {
            m_viewController->stopRecording();
            m_recordButton->setTitle("Record");
        }
    });
    addChild(m_recordButton);
    
    AGUIButtonGroup *modeButtonGroup = new AGUIButtonGroup();
    modeButtonGroup->init();
    
    /* freedraw button */
    float freedrawButtonWidth = 0.0095*AGStyle::oldGlobalScale;
    GLvertex3f modeButtonStartPos = m_viewController->fixedCoordinateForScreenCoordinate(CGPointMake(27.5, m_viewController->bounds().size.height-20));
    AGRenderInfoV freedrawRenderInfo;
    freedrawRenderInfo.numVertex = 5;
    freedrawRenderInfo.geoType = GL_LINE_LOOP;
    //    freedrawRenderInfo.geoOffset = 0;
    freedrawRenderInfo.geo = new GLvertex3f[freedrawRenderInfo.numVertex];
    float w = freedrawButtonWidth*(G_RATIO-1), h = w*0.3, t = h*0.75, rot = -M_PI/4;
    freedrawRenderInfo.geo[0] = rotateZ(GLvertex2f(-w/2,   -h/2), rot);
    freedrawRenderInfo.geo[1] = rotateZ(GLvertex2f( w/2-t, -h/2), rot);
    freedrawRenderInfo.geo[2] = rotateZ(GLvertex2f( w/2,      0), rot);
    freedrawRenderInfo.geo[3] = rotateZ(GLvertex2f( w/2-t,  h/2), rot);
    freedrawRenderInfo.geo[4] = rotateZ(GLvertex2f(-w/2,    h/2), rot);
    freedrawRenderInfo.color = AGStyle::lightColor();
    m_freedrawButton = new AGUIIconButton(modeButtonStartPos,
                                          GLvertex2f(freedrawButtonWidth, freedrawButtonWidth),
                                          freedrawRenderInfo);
    m_freedrawButton->init();
    m_freedrawButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    m_freedrawButton->setIconMode(AGUIIconButton::ICONMODE_CIRCLE);
    modeButtonGroup->addButton(m_freedrawButton, ^{
        //NSLog(@"freedraw");
        AGAnalytics::instance().eventFreedrawMode();
        m_viewController->setDrawMode(DRAWMODE_FREEDRAW);
    }, false);

    /* freedraw erase button */
    float freedrawEraseButtonWidth = freedrawButtonWidth;
    AGRenderInfoV freedrawEraseRenderInfo;
    freedrawEraseRenderInfo.numVertex = 18;
    freedrawEraseRenderInfo.geoType = GL_LINES;
    //    freedrawEraseRenderInfo.geoOffset = 0;
    freedrawEraseRenderInfo.geo = new GLvertex3f[freedrawEraseRenderInfo.numVertex];
    float W = freedrawEraseButtonWidth*(G_RATIO-1)*0.35f, _w = W*0.4f;
    float H = W*0.4f, _h = W*(G_RATIO-1);
    GLvertex3f geo[] = {
        { -W-_w, H+_h, 0 }, { -_w, H+_h, 0 },
        { -W-_w, H+_h, 0 }, { -W-_w, _h, 0 },
        { -W-_w, H+_h, 0 }, { _w, -_h, 0 },
        { -_w, H+_h, 0 }, { W+_w, -_h, 0 },
        { W+_w, -_h, 0 }, { W+_w, -H-_h, 0 },
        { W+_w, -H-_h, 0 }, { _w, -H-_h, 0 },
        { _w, -H-_h, 0 }, { _w, -_h, 0 },
        { _w, -_h, 0 }, { W+_w, -_h, 0 },
        { _w, -H-_h, 0 }, { -W-_w, _h, 0 },
    };
    memcpy(freedrawEraseRenderInfo.geo, geo, sizeof(GLvertex3f)*freedrawEraseRenderInfo.numVertex);
    freedrawEraseRenderInfo.color = AGStyle::lightColor();
    m_freedrawEraseButton = new AGUIIconButton(modeButtonStartPos + GLvertex3f(freedrawEraseButtonWidth*1.25, 0, 0),
                                          GLvertex2f(freedrawEraseButtonWidth, freedrawEraseButtonWidth),
                                          freedrawEraseRenderInfo);
    m_freedrawEraseButton->init();
    m_freedrawEraseButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    m_freedrawEraseButton->setIconMode(AGUIIconButton::ICONMODE_CIRCLE);
    modeButtonGroup->addButton(m_freedrawEraseButton, ^{
        //NSLog(@"freedraw_erase");
        //AGAnalytics::instance().eventFreedrawMode(); // XXX needed?
        m_viewController->setDrawMode(DRAWMODE_FREEDRAW_ERASE);
    }, false);

    /* node button */
    float nodeButtonWidth = freedrawButtonWidth;
    AGRenderInfoV nodeRenderInfo;
    nodeRenderInfo.numVertex = 10;
    nodeRenderInfo.geoType = GL_LINE_STRIP;
    nodeRenderInfo.geo = new GLvertex3f[nodeRenderInfo.numVertex];
    GeoGen::makeCircleStroke(nodeRenderInfo.geo, nodeRenderInfo.numVertex, nodeButtonWidth/2*(G_RATIO-1));
    nodeRenderInfo.color = AGStyle::lightColor();
    m_nodeButton = new AGUIIconButton(modeButtonStartPos + GLvertex3f(0, nodeButtonWidth*1.25, 0),
                                      GLvertex2f(nodeButtonWidth, nodeButtonWidth),
                                      nodeRenderInfo);
    m_nodeButton->init();
    m_nodeButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    m_nodeButton->setIconMode(AGUIIconButton::ICONMODE_CIRCLE);
    modeButtonGroup->addButton(m_nodeButton, ^{
        //NSLog(@"node");
        AGAnalytics::instance().eventNodeMode();
        m_viewController->setDrawMode(DRAWMODE_NODE);
    }, true);
    
    addChild(modeButtonGroup);
}

AGDashboard::~AGDashboard()
{
    
}

void AGDashboard::onInterfaceOrientationChange()
{
    CGPoint fileMenuPos = CGPointMake(10+m_fileMenu->size().x/2, 10+m_fileMenu->size().y/2);
    m_fileMenu->setPosition(m_viewController->fixedCoordinateForScreenCoordinate(fileMenuPos));
    
    CGPoint editMenuPos = CGPointMake(10+m_fileMenu->size().x*1.2+m_fileMenu->size().x/2, 10+m_fileMenu->size().y/2);
    m_editMenu->setPosition(m_viewController->fixedCoordinateForScreenCoordinate(editMenuPos));
    
    CGPoint settingsMenuPos = CGPointMake(10+m_fileMenu->size().x*2*1.2+m_fileMenu->size().x/2, 10+m_fileMenu->size().y/2);
    m_settingsMenu->setPosition(m_viewController->fixedCoordinateForScreenCoordinate(settingsMenuPos));
    
    CGPoint recordPos = CGPointMake(m_viewController->bounds().size.width-m_recordButton->size().x-20, 20+m_recordButton->size().y/2);
    m_recordButton->setPosition(m_viewController->fixedCoordinateForScreenCoordinate(recordPos));
    
    GLvertex3f modeButtonStartPos = m_viewController->fixedCoordinateForScreenCoordinate(CGPointMake(27.5, m_viewController->bounds().size.height-7.5-m_freedrawButton->size().y/2));
    m_freedrawButton->setPosition(modeButtonStartPos);
    m_freedrawEraseButton->setPosition(modeButtonStartPos + GLvertex3f(m_freedrawButton->size().y*1.25, 0, 0));
    m_nodeButton->setPosition(modeButtonStartPos + GLvertex3f(0, m_freedrawButton->size().y*1.25, 0));
}
