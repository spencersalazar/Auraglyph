//
//  AGTrainerView.h
//  Auraglyph
//
//  Created by Spencer Salazar on 12/3/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#import <UIKit/UIKit.h>


class LTKTraceGroup;


@interface AGTrainerView : UIView

- (void)clear;
- (LTKTraceGroup)currentTraceGroup;

@end

