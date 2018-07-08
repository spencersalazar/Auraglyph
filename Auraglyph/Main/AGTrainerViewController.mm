//
//  AGTrainerViewController.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/30/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGTrainerViewController.h"

#import "AGHandwritingRecognizer.h"

#include "LTKTypes.h"
#include "LTKTrace.h"
#include "LTKTraceGroup.h"

@interface AGTrainerViewController ()
{
    AGHandwritingRecognizerFigure _selectedFigure;
}

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
    _AGHandwritingRecognizer::numeralRecognizer().addSample([self.trainerView currentTraceGroup], _selectedFigure);
}

- (IBAction)discard
{
    [self.trainerView clear];
}

#pragma mark UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 10;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AGTrainerViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"FigureCell" forIndexPath:indexPath];
    [cell.title setTitle:[NSString stringWithFormat:@"%li", (long)indexPath.row] forState:UIControlStateNormal];
    [cell.title addTarget:self action:@selector(figureSelected:) forControlEvents:UIControlEventTouchUpInside];
    cell.title.tag = AG_FIGURE_0 + indexPath.row;
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    AGTrainerHeaderView *view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"FigureHeader" forIndexPath:indexPath];
    view.title.text = @"NUMERALS";
    
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


@interface AGTrainerView ()
{
    UIBezierPath *path;
    LTKTrace trace;
}


@end

@implementation AGTrainerView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    path = [UIBezierPath new];
}

- (void)drawRect:(CGRect)rect
{
    [[UIColor blackColor] setStroke];
    [path stroke];
}

- (void)clear
{
    [path removeAllPoints];
    trace = LTKTrace();
    
    [self setNeedsDisplay];
}

- (LTKTraceGroup)currentTraceGroup
{
    LTKTraceGroup traceGroup;
    traceGroup.addTrace(trace);
    
    return traceGroup;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    
    [path removeAllPoints];
    trace = LTKTrace();
    
    [path moveToPoint:p];

    vector<float> point;
    point.push_back(p.x);
    point.push_back(p.y);
    trace.addPoint(point);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];

    [path addLineToPoint:p];
    
    vector<float> point;
    point.push_back(p.x);
    point.push_back(p.y);
    trace.addPoint(point);
    
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}



@end
