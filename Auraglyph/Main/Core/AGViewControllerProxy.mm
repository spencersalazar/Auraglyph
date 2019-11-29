//
//  AGViewControllerProxy.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/28/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGViewControllerProxy.h"
#include "AGViewController-Private.h"
#include "AGAudioManager.h"
#include "AGTrainerViewController.h"
#include "AGAboutBox.h"

AGViewController_::AGViewController_(AGViewController *viewController)
{
    m_viewController = viewController;
}

AGViewController_::~AGViewController_()
{ }

void AGViewController_::createNew()
{
    [m_viewController _newDocument:YES];
}

void AGViewController_::save()
{
    [m_viewController _save:NO];
}

void AGViewController_::saveAs()
{
    [m_viewController _save:YES];
}

void AGViewController_::load()
{
    [m_viewController _openLoad];
}

void AGViewController_::loadExample()
{
    [m_viewController _openLoadExample];
}

void AGViewController_::showTrainer()
{
    [m_viewController presentViewController:m_viewController.trainer animated:YES completion:nil];
}

void AGViewController_::showAbout()
{
    AGAboutBox *aboutBox = new AGAboutBox([m_viewController fixedCoordinateForScreenCoordinate:CGPointMake(m_viewController.view.bounds.size.width/2,
                                                                                                           m_viewController.view.bounds.size.height/2)]);
    aboutBox->init();
    [m_viewController addTopLevelObject:aboutBox];
}

void AGViewController_::startRecording()
{
    [[AGAudioManager instance] startSessionRecording];
}

void AGViewController_::stopRecording()
{
    [[AGAudioManager instance] stopSessionRecording];
}

void AGViewController_::setDrawMode(AGDrawMode mode)
{
    m_viewController.drawMode = mode;
}

GLvertex3f AGViewController_::worldCoordinateForScreenCoordinate(CGPoint p)
{
    return [m_viewController worldCoordinateForScreenCoordinate:p];
}

GLvertex3f AGViewController_::fixedCoordinateForScreenCoordinate(CGPoint p)
{
    return [m_viewController fixedCoordinateForScreenCoordinate:p];
}

CGRect AGViewController_::bounds()
{
    return m_viewController.view.bounds;
}

void AGViewController_::addTopLevelObject(AGInteractiveObject *object)
{
    [m_viewController addTopLevelObject:object];
}

void AGViewController_::fadeOutAndDelete(AGInteractiveObject *object)
{
    [m_viewController fadeOutAndDelete:object];
}

void AGViewController_::addNodeToTopLevel(AGNode *node)
{
    [m_viewController addNode:node];
}

AGGraph *AGViewController_::graph()
{
    return [m_viewController graph];
}

void AGViewController_::showDashboard()
{
    [m_viewController showDashboard];
}

void AGViewController_::hideDashboard()
{
    [m_viewController hideDashboard];
}

void AGViewController_::showTutorial(AGTutorial *tutorial)
{
    [m_viewController showTutorial:tutorial];
}

