//
//  VideosViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/31/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Video.h"
#import "CSLContext.h"
#import "ImageScrollView.h"

@interface VideosViewController : UIViewController <UIScrollViewDelegate>

@property (weak, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (weak, nonatomic) CSLContext *cslContext;

@property (weak, nonatomic) NSSet* videos;
@property (weak, nonatomic) Video* video;

@property (weak, nonatomic) IBOutlet UILabel *videoIndex;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *layerSegmentedControl;
- (IBAction)forwardPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *backPressed;

@end
