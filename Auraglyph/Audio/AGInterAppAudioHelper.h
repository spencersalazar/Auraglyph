//
//  AGInterAppAudioHelper.h
//  Auraglyph
//
//  Created by Spencer Salazar on 10/20/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class AGInterAppAudioHelper;

@protocol AGInterAppAudioHelperDelegate

- (void)interAppAudioHelperDidConnectInterAppAudio:(AGInterAppAudioHelper *)helper;

@end

@interface AGInterAppAudioHelper : NSObject

@property id<AGInterAppAudioHelperDelegate> delegate;

@property AudioUnit audioUnit;
@property NSString *productName;
@property OSType productManufacturer;

- (void)setup;
- (BOOL)isInterAppAudio;

@end
