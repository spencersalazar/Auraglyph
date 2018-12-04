//
//  AGTrainerViewController.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/30/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGTrainerViewController.h"
#import "AGHandwritingRecognizer.h"
#import "AGTrainerView.h"

#include "LTKTypes.h"
#include "LTKTrace.h"
#include "LTKTraceGroup.h"

enum AGTrainerSection
{
    kAGTrainerSection_Numerals = 0,
    kAGTrainerSection_Shapes,
};

static NSString *AGTrainerShapeLabel[] = {
    @"\u25EF",
    @"\u25A2",
};


@interface AGTrainerViewCell : UICollectionViewCell
@property (strong) IBOutlet UIButton *title;
@end


@interface AGTrainerHeaderView : UICollectionReusableView
@property (strong) IBOutlet UILabel *title;
@end


@interface AGTrainerViewController ()
{
    AGHandwritingRecognizerFigure _selectedFigure;
}

@property (strong) IBOutlet UICollectionView *figureCollectionView;
@property (strong) IBOutlet AGTrainerView *trainerView;
@property (strong) IBOutlet UILabel *selectedFigureLabel;

- (IBAction)done;
- (IBAction)accept;
- (IBAction)discard;

- (void)figureSelected:(id)sender;

@end

@implementation AGTrainerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self.figureCollectionView registerNib:[UINib nibWithNibName:@"AGTrainerViewCell" bundle:nil]
                forCellWithReuseIdentifier:@"FigureCell"];
    [self.figureCollectionView registerNib:[UINib nibWithNibName:@"AGTrainerHeaderView" bundle:nil]
                forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                       withReuseIdentifier:@"FigureHeader"];
    
    self.selectedFigureLabel.text = @"";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)figureSelected:(id)sender
{
    _selectedFigure = (AGHandwritingRecognizerFigure) [sender tag];
    self.selectedFigureLabel.text = [sender currentTitle];
    
    [self.trainerView clear];
}

#pragma mark IBActions

- (IBAction)done
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)accept
{
    AGHandwritingRecognizer *hwr = [AGHandwritingRecognizer instance];
    if([hwr figureIsNumeral:_selectedFigure])
    {
        [hwr addSample:[self.trainerView currentTraceGroup]
            forNumeral:_selectedFigure];
    }
    else if([hwr figureIsShape:_selectedFigure])
    {
        [hwr addSample:[self.trainerView currentTraceGroup]
            forShape:_selectedFigure];
    }
}

- (IBAction)discard
{
    [self.trainerView clear];
}

#pragma mark UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 2;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    switch(section)
    {
        case kAGTrainerSection_Numerals:
            return 10;
        case kAGTrainerSection_Shapes:
            return 2;
    }
    
    return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AGTrainerViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"FigureCell" forIndexPath:indexPath];
    [cell.title addTarget:self action:@selector(figureSelected:) forControlEvents:UIControlEventTouchUpInside];

    switch(indexPath.section)
    {
        case kAGTrainerSection_Numerals: {
            [cell.title setTitle:[NSString stringWithFormat:@"%li", (long)indexPath.row] forState:UIControlStateNormal];
            cell.title.tag = AG_FIGURE_0 + indexPath.row;
        } break;

        case kAGTrainerSection_Shapes: {
            [cell.title setTitle:AGTrainerShapeLabel[indexPath.row] forState:UIControlStateNormal];
            cell.title.tag = AG_FIGURE_CIRCLE + indexPath.row;
            return cell;
        } break;
    }
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    AGTrainerHeaderView *view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"FigureHeader" forIndexPath:indexPath];
    
    switch(indexPath.section)
    {
        case kAGTrainerSection_Numerals: view.title.text = @"NUMERALS"; break;
        case kAGTrainerSection_Shapes: view.title.text = @"SHAPES"; break;
    }
    
    return view;
}

@end

@implementation AGTrainerViewCell

@synthesize title;

@end

@implementation AGTrainerHeaderView

@synthesize title;

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.title.transform = CGAffineTransformMakeRotation(-M_PI/2.0);
}

@end

