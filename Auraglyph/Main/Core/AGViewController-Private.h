//
//  AGViewController-Private.h
//  Auraglyph
//
//  Created by Spencer Salazar on 11/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGViewController.h"

@class AGAudioManager;
@class AGTrainerViewController;

@interface AGViewController (Private)

@property (nonatomic) AGDrawMode drawMode;

- (AGTrainerViewController *)trainer;

- (void)removeFromTouchCapture:(AGInteractiveObject *)object;
- (void)setupGL;
- (void)tearDownGL;
- (void)initUI;
- (void)_updateFixedUIPosition;
- (void)updateMatrices;
- (void)renderEdit;

- (void)_save:(BOOL)saveAs;
- (void)_openLoad;
- (void)_clearDocument;
- (void)_newDocument:(BOOL)createDefaultOutputNode;
- (void)_loadDocument:(AGDocument &)doc;
- (void)_openLoadExample;

@end

