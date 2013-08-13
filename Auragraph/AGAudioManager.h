//
//  AGAudioManager.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/13/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>

class AGAudioOutputNode;

@interface AGAudioManager : NSObject

@property (nonatomic) AGAudioOutputNode * outputNode;

@end
