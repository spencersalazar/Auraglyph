//
//  AGTrainerViewController.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/30/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import <UIKit/UIKit.h>


@class AGTrainerView;

@interface AGTrainerViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>

@property (strong) IBOutlet UICollectionView *figureCollectionView;
@property (strong) IBOutlet AGTrainerView *trainerView;
@property (strong) IBOutlet UILabel *selectedFigureLabel;

- (IBAction)done;
- (IBAction)accept;
- (IBAction)discard;

@end


@interface AGTrainerViewCell : UICollectionViewCell
@property (strong) IBOutlet UIButton *title;

@end


@interface AGTrainerHeaderView : UICollectionReusableView
@property (strong) IBOutlet UILabel *title;

@end


class LTKTraceGroup;

@interface AGTrainerView : UIView

- (void)clear;
- (LTKTraceGroup)currentTraceGroup;

@end
