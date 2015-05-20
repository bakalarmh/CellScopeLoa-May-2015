//
//  AugmentedMotionScopeViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/19/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LLCamera.h"
#import "CSLContext.h"

@interface AugmentedMotionScopeViewController : UIViewController <CGProcessingDelegate>

@property (nonatomic, weak) CSLContext* cslContext;
@property (weak, nonatomic) IBOutlet UIImageView *augmentedImageView;

@end
