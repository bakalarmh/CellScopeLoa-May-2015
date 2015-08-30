
//
//  MotionAnalysis.m
//  CellScopeLoa

#import "MotionAnalysis.h"
#import "UIImage+OpenCV.h"
#import "FrameBuffer.h"


@implementation MAMotionObjects

@end

@implementation MotionAnalysis {
    dispatch_queue_t backgroundQueue;
    NSMutableArray* frameBufferList;
    NSMutableDictionary* resultsDict;
    NSMutableArray* wormObjects;
    
    float numWorms;
    float numSeconds;
}

-(id)initWithWidth:(NSInteger)width Height:(NSInteger)height
            Frames:(NSInteger)frames
        VideoCount:(NSInteger)maxVideos
{
    self = [super init];
    
    // Number of independent seconds to observe
    numSeconds = 5.0;
    
    frameBufferList = [[NSMutableArray alloc] init];
    backgroundQueue = dispatch_queue_create("com.cellscopeloa.analysis.bgqueue", NULL);
    
    return self;
}

- (void)suspendProcessing
{
    if (backgroundQueue != nil) {
        dispatch_suspend(backgroundQueue);
    }
}

+ (float)ComputeFocusMetric:(FrameBuffer*)frameBuffer
{
    //crop the image
    cv::Mat firstMat = [frameBuffer getFrameAtIndex:0];
    cv::Rect rect1;
    rect1.x = 480/2-200/2;
    rect1.y = 360/2-200/2;
    rect1.width = 200;
    rect1.height = 200;
    cv::Mat croppedImage = firstMat(rect1);
    
    //generate the mask
    cv::Mat mask;
    threshold(croppedImage, mask, 210, 255, CV_THRESH_BINARY_INV);
    
    //calc the focus metric
    cv::Mat lap;
    cv::Laplacian(croppedImage, lap, CV_64F);
    cv::Scalar mu, sigma;
    cv::meanStdDev(lap, mu, sigma, mask);

    double focusMeasure = sigma.val[0]*sigma.val[0];
    double normFocusMeasure = focusMeasure/100.0;
    
    return normFocusMeasure;
}

+ (BOOL)frameBufferIsBlack:(FrameBuffer*)frameBuffer index:(NSNumber*)index
{
    //crop the image
    cv::Mat firstMat = [frameBuffer getFrameAtIndex:0];
    double min, max;
    cv::minMaxLoc(firstMat, &min, &max);
    if (max > 0) {
        return NO;
    }
    else {
        return YES;
    }
}

// Called by the TestViewController
- (void)processFrameBuffer:(FrameBuffer*)frameBuffer withResourceURL:(NSString*)videoURL
{
    [frameBufferList addObject:frameBuffer];
    dispatch_async(backgroundQueue, ^(void) {
        
        // Pop the latest frame buffer off of the stack
        FrameBuffer* localFrameBuffer = [frameBufferList lastObject];
        [frameBufferList removeLastObject];
        
        // Process the frame buffer
        resultsDict = [[NSMutableDictionary alloc] init];
        [self processFramesForMovie:localFrameBuffer];
        
        // Release the frame buffer
        [localFrameBuffer releaseFrameBuffers];
        
        // Send results to any listeners
        NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setObject:videoURL forKey:@"ResourceURL"];
        
        NSNumber* focusMetric = [resultsDict objectForKey:@"FocusMetric"];
        [userInfo setObject:focusMetric forKey:@"FocusMetric"];
        
        NSString* errorString = [resultsDict objectForKey:@"ErrorMessage"];
        if (errorString == nil) {
            NSLog(@"No errors");
            NSMutableDictionary* motionObjects = [resultsDict objectForKey:@"MotionObjects"];
            float averageCount = (motionObjects.count/numSeconds);  // x, y, start, end
            
            // Backup motion metric
            NSNumber* surfMotionMetric = [resultsDict objectForKey:@"SurfMotionMetric"];
            NSNumber* diffMotionMetric = [resultsDict objectForKey:@"DiffMotionMetric"];
            
            [userInfo setObject:motionObjects forKey:@"MotionObjects"];
            [userInfo setObject:[NSNumber numberWithFloat:averageCount] forKey:@"AverageCount"];
            [userInfo setObject:surfMotionMetric forKey:@"SurfMotionMetric"];
            [userInfo setObject:diffMotionMetric forKey:@"DiffMotionMetric"];
        }
        else {
            [userInfo setObject:errorString forKey:@"ErrorString"];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"eventAnalysisComplete" object:self userInfo:userInfo];
    });
}

- (void)processFramesForMovie:(FrameBuffer*) frameBuffer {
    
    // Parameter space!!! MHB MD
    float bubbleLimit = 480*360*0.25;
    // Algorithm parameters
    int framesToAvg = 7;
    int framesToSkip = 1;
    int avgFrames = framesToAvg/framesToSkip;
    int frameIdx = 0;
    int bubbleThresh=235; //above this threshold, bubbles are identified
    int backgroundSize=75; //these are the kernel sizes used to estimate the background
    int backgroundSize2=75;
    int backgroundSize3=75;
    int backgroundSize4=75;
    int backgroundSize5=75;
    int gaussKernel00=5; //kernel size used for blurring
    int minBack=2400; //this is the max val that the background can climb to- 4000 for new movies
    int maxBack=65535;
    double backValCorr=1; //multiplier for detected background level. happens AFTER maxBack is capped
    int corrGausSize=31; //these are used to generate the correlation gaussian
    int corrGausSig=500;
    int thresh=5; //the minimum value of the local maxima
    int matchingSize=17; //the minimum size of the local maxima
    int minHessian = 50; //for surf detector
    // Is there flow in the capillary?
    BOOL flow = [self computeFlowForBuffer:frameBuffer];
    //NSLog(@"Flow: %@", flow ? @"YES" : @"NO"); //loaTK comment
    
    //loaTK add
    if (flow==YES) {
        
        NSLog(@"Flow,%i", 1);
        
    }
    else {
        NSLog(@"Flow,%i", 0);
    }
    
    // Initialize the wormObjects array
    wormObjects = [[NSMutableArray alloc] init];
    numWorms = 0;
    // Movie dimensions
    int rows = 360;
    int cols = 480;
    
    
    // Focus parameter
    double focusMeasure = 0.0;
    double normFocusMeasure = 0.0;
    // Matrix for storing normalized frames
    cv::Mat movieFrameMatNorm=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNormOld;
    cv::Mat movieFrameMatIllum;
    
    // Temporary matrices for image processing
    cv::Mat movieFrameMatOld;
    cv::Mat movieFrameMatCum(rows,cols, CV_16UC1, cv::Scalar::all(0));
    cv::Mat movieFrameMatFirst;
    cv::Mat movieFrameMatDiff= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiffTmp;
    cv::Mat movieFrameMat;
    cv::Mat movieFrameMatBW;
    cv::Mat movieFrameMatBWInv;
    cv::Mat movieFrameMatDiff1= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff2= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff3= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff4= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff5= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMattDiff1Erode;
    cv::Mat movieFrameMattDiff2Erode;
    cv::Mat movieFrameMattDiff3Erode;
    cv::Mat movieFrameMattDiff4Erode;
    cv::Mat movieFrameMattDiff5Erode;
    
    // MHB Use the mask channel provided in the frame buffer
    cv::Mat bloodMask = [frameBuffer getMaskAtIndex:0];
    cv::medianBlur(bloodMask,bloodMask,35);
    
    //generate BW mask
    movieFrameMat = [frameBuffer getFrameAtIndex:0];
    // threshold(movieFrameMat, movieFrameMatBW, bubbleThresh, 255, CV_THRESH_BINARY);
    threshold(bloodMask, movieFrameMatBW, bubbleThresh, 255, CV_THRESH_BINARY);

    
    int blurKernel=7;
    cv::Mat element0 = getStructuringElement(CV_SHAPE_ELLIPSE, cv::Size(blurKernel,blurKernel ), cv::Point( (blurKernel-1)/2,(blurKernel-1)/2 ));
    cv::morphologyEx(movieFrameMatBW,movieFrameMatBW, CV_MOP_DILATE, element0 );
    movieFrameMatBWInv =  cv::Scalar::all(255) - movieFrameMatBW.clone();
    movieFrameMatBW.convertTo(movieFrameMatBW, CV_32FC1);
    movieFrameMatBW=movieFrameMatBW*255;
    movieFrameMatBWInv.convertTo(movieFrameMatBWInv, CV_32FC1);
    movieFrameMatBWInv=movieFrameMatBWInv/255;
    
    int i = 0;
    frameIdx = 0;
    // Compute difference image from current movie
    while(frameIdx < (frameBuffer.numFrames.integerValue)) {
        while(i < avgFrames) {
            int bufferIdx = frameIdx;
            //read the image and do illum correction
            movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
            movieFrameMat.convertTo(movieFrameMat, CV_32FC1);
            //cv::divide(movieFrameMat,movieFrameMatIllum,movieFrameMat);
            cv::multiply(movieFrameMat,movieFrameMatBWInv,movieFrameMat);
            movieFrameMat.convertTo(movieFrameMat, CV_16UC1);
            if (i==0){
                
                
                // Generate a robust focus metric
                //crop the image
                cv::Mat firstMat = [frameBuffer getFrameAtIndex:0];
                cv::Rect rect1;
                rect1.x = 480/2-200/2;
                rect1.y = 360/2-200/2;
                rect1.width = 200;
                rect1.height = 200;
                cv::Mat croppedImage = firstMat(rect1);
                //generate the mask
                cv::Mat mask;
                threshold(croppedImage, mask, bubbleThresh, 255, CV_THRESH_BINARY_INV);
                //calc the focus metric
                cv::Mat lap;
                cv::Laplacian(croppedImage, lap, CV_64F);
                cv::Scalar mu, sigma;
                cv::meanStdDev(lap, mu, sigma, mask);
                focusMeasure = sigma.val[0]*sigma.val[0];
                normFocusMeasure = focusMeasure/100.0;
                NSLog(@"normfocus, %f", normFocusMeasure);
            }
            if (i == 0){
                movieFrameMatOld=movieFrameMat;
                movieFrameMat.release();
                movieFrameMat=cv::Mat();
            }
            else {
                movieFrameMatCum = movieFrameMatCum + movieFrameMat;
                movieFrameMatOld.release();
                movieFrameMatOld=cv::Mat();
                movieFrameMatOld=movieFrameMat;
                movieFrameMat.release();
                movieFrameMat=cv::Mat();
            }
            i=i+1;
            frameIdx = frameIdx + framesToSkip;
        }
        if (i == avgFrames){
            movieFrameMatNormOld=movieFrameMatCum.clone()/i;
        }
        if (i >= avgFrames) {
            int bufferIdx = frameIdx;
            movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
            movieFrameMat.convertTo(movieFrameMat, CV_32FC1);
            cv::multiply(movieFrameMat,movieFrameMatBWInv,movieFrameMat);
            movieFrameMat.convertTo(movieFrameMat, CV_16UC1);
            
            int firstBufferIdx = (frameIdx-avgFrames);
            
            movieFrameMatFirst = [frameBuffer getFrameAtIndex:firstBufferIdx];
            movieFrameMatFirst.convertTo(movieFrameMatFirst, CV_32FC1);
            
            cv::multiply(movieFrameMatFirst,movieFrameMatBWInv,movieFrameMatFirst);
            movieFrameMatFirst.convertTo(movieFrameMatFirst, CV_16UC1);
            movieFrameMatCum = movieFrameMatCum - movieFrameMatFirst + movieFrameMat;
            movieFrameMat.release();
            movieFrameMat=cv::Mat();
            movieFrameMatFirst.release();
            movieFrameMatFirst=cv::Mat();
            cv::divide(movieFrameMatCum, avgFrames, movieFrameMatNorm);
            cv::absdiff(movieFrameMatNormOld, movieFrameMatNorm, movieFrameMatDiffTmp);
            movieFrameMatNormOld.release();
            movieFrameMatNormOld=cv::Mat();
            if (i<=34) {
                movieFrameMatDiff1 = movieFrameMatDiff1 + movieFrameMatDiffTmp;
            }
            else if  (i<=62) {
                movieFrameMatDiff2 = movieFrameMatDiff2 + movieFrameMatDiffTmp;
            }
            else if (i<=90) {
                movieFrameMatDiff3 = movieFrameMatDiff3 + movieFrameMatDiffTmp;
            }
            else if (i<=118) {
                movieFrameMatDiff4 = movieFrameMatDiff4 + movieFrameMatDiffTmp;
            }
            else if (i<=146) {
                movieFrameMatDiff5 = movieFrameMatDiff5 + movieFrameMatDiffTmp;
            }
            movieFrameMatDiffTmp.release();
            movieFrameMatDiffTmp=cv::Mat();
        }
        movieFrameMatNormOld=movieFrameMatNorm.clone();
        movieFrameMatNorm.release();
        movieFrameMatNorm=cv::Mat();
        frameIdx = frameIdx + framesToSkip;
        i = i+1;
    }
    
    
    movieFrameMatBW.convertTo(movieFrameMatBW, CV_16UC1);
    movieFrameMatBWInv.convertTo(movieFrameMatBWInv, CV_16UC1);
    
    cv::Mat movieFrameMatDiff1Surf=movieFrameMatDiff1.clone();
    movieFrameMatDiff1Surf.convertTo(movieFrameMatDiff1Surf, CV_8UC1);
    
    cv::Mat movieFrameMatDiff2Surf=movieFrameMatDiff2.clone();
    movieFrameMatDiff2Surf.convertTo(movieFrameMatDiff2Surf, CV_8UC1);
    
    cv::Mat movieFrameMatDiff3Surf=movieFrameMatDiff3.clone();
    movieFrameMatDiff3Surf.convertTo(movieFrameMatDiff3Surf, CV_8UC1);
    
    cv::Mat movieFrameMatDiff4Surf=movieFrameMatDiff4.clone();
    movieFrameMatDiff4Surf.convertTo(movieFrameMatDiff4Surf, CV_8UC1);
    
    cv::Mat movieFrameMatDiff5Surf=movieFrameMatDiff5.clone();
    movieFrameMatDiff5Surf.convertTo(movieFrameMatDiff5Surf, CV_8UC1);
    
    
    //detect features
    cv::SurfFeatureDetector detector(minHessian);
    std::vector<cv::KeyPoint> keypoints;
    detector.detect(movieFrameMatDiff1Surf, keypoints);
    unsigned long numPoints1=keypoints.size();
    detector.detect(movieFrameMatDiff2Surf, keypoints);
    unsigned long numPoints2=keypoints.size();
    detector.detect(movieFrameMatDiff3Surf, keypoints);
    unsigned long numPoints3=keypoints.size();
    detector.detect(movieFrameMatDiff4Surf, keypoints);
    unsigned long numPoints4=keypoints.size();
    detector.detect(movieFrameMatDiff5Surf, keypoints);
    unsigned long numPoints5=keypoints.size();
    NSLog(@"numsurf, %ld,%ld,%ld,%ld,%ld",numPoints1,numPoints2,numPoints3,numPoints4,numPoints5);
    
    //read out total intensity
    cv::Scalar sumDiff1=cv::sum(movieFrameMatDiff1);
    cv::Scalar sumDiff2=cv::sum(movieFrameMatDiff2);
    cv::Scalar sumDiff3=cv::sum(movieFrameMatDiff3);
    cv::Scalar sumDiff4=cv::sum(movieFrameMatDiff4);
    cv::Scalar sumDiff5=cv::sum(movieFrameMatDiff5);
    NSLog(@"diffsums, %f, %f, %f, %f, %f", sumDiff1[0],sumDiff2[0],sumDiff3[0],sumDiff4[0],sumDiff5[0]);
    
    movieFrameMatDiff1=movieFrameMatDiff1*600;
    movieFrameMatDiff2=movieFrameMatDiff2*600;
    movieFrameMatDiff3=movieFrameMatDiff3*600;
    movieFrameMatDiff4=movieFrameMatDiff4*600;
    movieFrameMatDiff5=movieFrameMatDiff5*600;
    double trash;
    double maxVal;
    cv::minMaxLoc(movieFrameMatDiff5, &trash, &maxVal);
    NSLog(@"maxval after loop is %f", maxVal);
    
    GaussianBlur(movieFrameMatDiff1,movieFrameMatDiff1,cv::Size(gaussKernel00,gaussKernel00),0,0,cv::BORDER_REPLICATE);
    GaussianBlur(movieFrameMatDiff2,movieFrameMatDiff2,cv::Size(gaussKernel00,gaussKernel00),0,0,cv::BORDER_REPLICATE);
    GaussianBlur(movieFrameMatDiff3,movieFrameMatDiff3,cv::Size(gaussKernel00,gaussKernel00),0,0,cv::BORDER_REPLICATE);
    GaussianBlur(movieFrameMatDiff4,movieFrameMatDiff4,cv::Size(gaussKernel00,gaussKernel00),0,0,cv::BORDER_REPLICATE);
    GaussianBlur(movieFrameMatDiff5,movieFrameMatDiff5,cv::Size(gaussKernel00,gaussKernel00),0,0,cv::BORDER_REPLICATE);
    cv::Scalar sum11=cv::sum(movieFrameMatDiff1);
    cv::Scalar sum22=cv::sum(movieFrameMatDiff2);
    cv::Scalar sum33=cv::sum(movieFrameMatDiff3);
    cv::Scalar sum44=cv::sum(movieFrameMatDiff4);
    cv::Scalar sum55=cv::sum(movieFrameMatDiff5);
    
    
    NSLog(@"done with loop, sums are %f, %f, %f, %f, %f", sum11[0],sum22[0],sum33[0],sum44[0],sum55[0]);
    
    //estimate background
    cv::Mat movieFrameMatDiff1Open;
    cv::Mat element = getStructuringElement(CV_SHAPE_ELLIPSE, cv::Size(21,21 ), cv::Point( (21-1)/2,(21-1)/2 ));
    cv::morphologyEx(movieFrameMatDiff1,movieFrameMatDiff1Open, CV_MOP_OPEN, element );
    movieFrameMatDiff1=movieFrameMatDiff1-movieFrameMatDiff1Open;
    
    cv::Mat movieFrameMatDiff2Open;
    cv::morphologyEx(movieFrameMatDiff2,movieFrameMatDiff2Open, CV_MOP_OPEN, element );
    movieFrameMatDiff2=movieFrameMatDiff2-movieFrameMatDiff2Open;
    
    
    cv::Mat movieFrameMatDiff3Open;
    cv::morphologyEx(movieFrameMatDiff3,movieFrameMatDiff3Open, CV_MOP_OPEN, element );
    movieFrameMatDiff3=movieFrameMatDiff3-movieFrameMatDiff3Open;
    
    cv::Mat movieFrameMatDiff4Open;
    cv::morphologyEx(movieFrameMatDiff4,movieFrameMatDiff4Open, CV_MOP_OPEN, element );
    movieFrameMatDiff4=movieFrameMatDiff4-movieFrameMatDiff4Open;
    
    cv::Mat movieFrameMatDiff5Open;
    cv::morphologyEx(movieFrameMatDiff5,movieFrameMatDiff5Open, CV_MOP_OPEN, element );
    movieFrameMatDiff5=movieFrameMatDiff5-movieFrameMatDiff5Open;
    
    
    cv::Mat backgroundConvMat= cv::Mat::ones(backgroundSize,backgroundSize, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize*backgroundSize);
    //new background calcs1
    cv::Mat movieFrameMatDiff1Back=movieFrameMatDiff1+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff1Back, movieFrameMatDiff1Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    
    double backVal1;
    double maxValTrash1;
    cv::minMaxLoc(movieFrameMatDiff1Back, &backVal1, &maxValTrash1);
    //new background calcs2
    backgroundConvMat= cv::Mat::ones(backgroundSize2,backgroundSize2, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize2*backgroundSize2);
    cv::Mat movieFrameMatDiff2Back=movieFrameMatDiff2+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff2Back, movieFrameMatDiff2Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    
    
    double backVal2;
    double maxValTrash2;
    cv::minMaxLoc(movieFrameMatDiff2Back, &backVal2, &maxValTrash2);
    
    //new background calcs3
    backgroundConvMat= cv::Mat::ones(backgroundSize3,backgroundSize3, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize3*backgroundSize3);
    cv::Mat movieFrameMatDiff3Back=movieFrameMatDiff3+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff3Back, movieFrameMatDiff3Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    
    
    double backVal3;
    double maxValTrash3;
    cv::minMaxLoc(movieFrameMatDiff3Back, &backVal3, &maxValTrash3);
    //new background calcs4
    backgroundConvMat= cv::Mat::ones(backgroundSize4,backgroundSize4, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize4*backgroundSize4);
    cv::Mat movieFrameMatDiff4Back=movieFrameMatDiff4+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff4Back, movieFrameMatDiff4Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    
    double backVal4;
    double maxValTrash4;
    cv::minMaxLoc(movieFrameMatDiff4Back, &backVal4, &maxValTrash4);
    //new background calcs5
    backgroundConvMat= cv::Mat::ones(backgroundSize5,backgroundSize5, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize5*backgroundSize5);
    cv::Mat movieFrameMatDiff5Back=movieFrameMatDiff5+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff5Back, movieFrameMatDiff5Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    
    double backVal5;
    double maxValTrash5;
    cv::minMaxLoc(movieFrameMatDiff5Back, &backVal5, &maxValTrash5);
    NSLog(@"backvals, %f, %f, %f, %f, %f", backVal1,backVal2,backVal3,backVal4,backVal5);
    
    double backValCorr1=backValCorr;
    double backValCorr2=backValCorr;
    double backValCorr3=backValCorr;
    double backValCorr4=backValCorr;
    double backValCorr5=backValCorr;
    backVal1=backVal1*backValCorr1;
    backVal2=backVal2*backValCorr2;
    backVal3=backVal3*backValCorr3;
    backVal4=backVal4*backValCorr4;
    backVal5=backVal5*backValCorr5;
    
    if (backVal1<minBack) {
        backVal1=minBack;
    }
    else if (backVal1>maxBack) {
        backVal1=maxBack;
    }
    if (backVal2<minBack) {
        backVal2=minBack;
    }
    else if (backVal2>maxBack) {
        backVal2=maxBack;
    }
    if (backVal3<minBack) {
        backVal3=minBack;
    }
    else if (backVal3>maxBack) {
        backVal3=maxBack;
    }
    if (backVal4<minBack) {
        backVal4=minBack;
    }
    else if (backVal4>maxBack) {
        backVal4=maxBack;
    }
    
    if (backVal5<minBack) {
        backVal5=minBack;
    }
    else if (backVal5>maxBack) {
        backVal5=maxBack;
    }
    
    movieFrameMatDiff1=movieFrameMatDiff1-backVal1;
    movieFrameMatDiff2=movieFrameMatDiff2-backVal2;
    movieFrameMatDiff3=movieFrameMatDiff3-backVal3;
    movieFrameMatDiff4=movieFrameMatDiff4-backVal4;
    movieFrameMatDiff5=movieFrameMatDiff5-backVal5;
    
    //median filter n times
    int n=3;
    for(int i=0; i<n; i++) {
        cv::medianBlur(movieFrameMatDiff1,movieFrameMatDiff1,3);
        cv::medianBlur(movieFrameMatDiff2,movieFrameMatDiff2,3);
        cv::medianBlur(movieFrameMatDiff3,movieFrameMatDiff3,3);
        cv::medianBlur(movieFrameMatDiff4,movieFrameMatDiff4,3);
        cv::medianBlur(movieFrameMatDiff5,movieFrameMatDiff5,3);
    }
    //erode
    int erosionSize=2;
    element = getStructuringElement(0, cv::Size( 2*erosionSize + 1, 2*erosionSize+1 ),cv::Point( erosionSize, erosionSize));
    
    cv::morphologyEx( movieFrameMatDiff1, movieFrameMatDiff1,CV_MOP_ERODE, element );
    cv::morphologyEx( movieFrameMatDiff2, movieFrameMatDiff2, CV_MOP_ERODE,element );
    cv::morphologyEx( movieFrameMatDiff3, movieFrameMatDiff3, CV_MOP_ERODE,element );
    cv::morphologyEx( movieFrameMatDiff4, movieFrameMatDiff4, CV_MOP_ERODE,element );
    cv::morphologyEx( movieFrameMatDiff5, movieFrameMatDiff5, CV_MOP_ERODE,element );
    
    GaussianBlur(movieFrameMatDiff1,movieFrameMatDiff1,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff2,movieFrameMatDiff2,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff3,movieFrameMatDiff3,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff4,movieFrameMatDiff4,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff5,movieFrameMatDiff5,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    //convolve with mean subtracted gaussian
    cv::Mat gaussKer0=cv::getGaussianKernel(corrGausSize, corrGausSig, CV_32F ); //this code generates the mean subtracted gaussian used for correlation to clear up potential worm fields
    cv::Mat gaussKer= gaussKer0 * gaussKer0.t();
    cv::Scalar aveGaussKer=cv::mean(gaussKer);
    gaussKer=gaussKer-aveGaussKer[0];
    
    movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_32F);
    cv::filter2D(movieFrameMatDiff1,movieFrameMatDiff1,-1,gaussKer, cv::Point(-1,-1));
    
    //@TODO make sure this doesn't saturate
    movieFrameMatDiff1=movieFrameMatDiff1*25500;
    movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_16UC1);
    movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_32F);
    cv::filter2D(movieFrameMatDiff2,movieFrameMatDiff2,-1,gaussKer, cv::Point(-1,-1));
    movieFrameMatDiff2=movieFrameMatDiff2*25500;
    movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_16UC1);
    movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_32F);
    cv::filter2D(movieFrameMatDiff3,movieFrameMatDiff3,-1,gaussKer, cv::Point(-1,-1));
    movieFrameMatDiff3=movieFrameMatDiff3*25500;
    movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_16UC1);
    movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_32F);
    cv::filter2D(movieFrameMatDiff4,movieFrameMatDiff4,-1,gaussKer, cv::Point(-1,-1));
    movieFrameMatDiff4=movieFrameMatDiff4*25500;
    movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_16UC1);
    movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_32F);
    cv::filter2D(movieFrameMatDiff5,movieFrameMatDiff5,-1,gaussKer, cv::Point(-1,-1));
    movieFrameMatDiff5=movieFrameMatDiff5*25500;
    movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_16UC1);
    
    movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_8UC1);
    movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_8UC1);
    movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_8UC1);
    movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_8UC1);
    movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_8UC1);
    
    //detect local maxima
    [self getLocalMaxima:movieFrameMatDiff1: matchingSize: thresh: 0:1:32];
    movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_8UC1);
    cv::Mat movieFrameMatForWatGray;
    threshold(movieFrameMatDiff1, movieFrameMatForWatGray, 1, 255, CV_THRESH_TOZERO);
    threshold(movieFrameMatDiff1, movieFrameMatDiff1, 1, 255, CV_THRESH_BINARY);
    cv::Mat movieFrameMatDiff1ForWat=movieFrameMatDiff1.clone();
    [self getLocalMaxima:movieFrameMatDiff2: matchingSize: thresh: 0:33:60];
    movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_8UC1);
    threshold(movieFrameMatDiff2, movieFrameMatForWatGray, 1, 255, CV_THRESH_TOZERO);
    threshold(movieFrameMatDiff2, movieFrameMatDiff2, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff2.clone();
    [self getLocalMaxima:movieFrameMatDiff3: matchingSize: thresh: 0:61:90];
    movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_8UC1);
    threshold(movieFrameMatDiff3, movieFrameMatDiff3, 1, 255, CV_THRESH_BINARY);
    threshold(movieFrameMatDiff3, movieFrameMatDiff3, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff3.clone();
    [self getLocalMaxima:movieFrameMatDiff4: matchingSize: thresh: 0:91:120];
    movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_8UC1);
    threshold(movieFrameMatDiff4, movieFrameMatDiff4, 1, 255, CV_THRESH_BINARY);
    threshold(movieFrameMatDiff4, movieFrameMatDiff4, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff4.clone();
    [self getLocalMaxima:movieFrameMatDiff5: matchingSize: thresh: 0:121:150];
    movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_8UC1);
    threshold(movieFrameMatDiff5, movieFrameMatDiff5, 1, 255, CV_THRESH_BINARY);
    threshold(movieFrameMatDiff5, movieFrameMatDiff5, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff5.clone();
    numWorms=numWorms/5;
    cv::Scalar usedSum=cv::sum(movieFrameMatBWInv);
    float totalArea = 480*360;
    float ignoredArea = 480*360 - usedSum[0];
    
    // Do not perform any area compensation
    //numWorms=numWorms*(totalArea/(totalArea-ignoredArea));
    
    NSLog(@"numWorms, %f", numWorms);
    NSLog(@"Area fraction, %f", (totalArea-ignoredArea)/totalArea);
    movieFrameMatDiff.release();
    movieFrameMatDiff1.release();
    movieFrameMatDiff2.release();
    movieFrameMatDiff3.release();
    movieFrameMatDiff4.release();
    movieFrameMatDiff5.release();
    movieFrameMatBW.release();
    
    [resultsDict setObject:wormObjects forKey:@"MotionObjects"];
    [resultsDict setObject:[NSNumber numberWithFloat:normFocusMeasure] forKey:@"FocusMetric"];
    [resultsDict setObject:[NSNumber numberWithFloat:0.0] forKey:@"SurfMotionMetric"];
    [resultsDict setObject:[NSNumber numberWithFloat:0.0] forKey:@"DiffMotionMetric"];
    
    // Register error messages
    if (ignoredArea > bubbleLimit) {
        [resultsDict setObject:@"BubbleError" forKey:@"ErrorMessage"];
    }
    // Flow error message supersedes all messages
    if (flow) {
        [resultsDict setObject:@"FlowError" forKey:@"ErrorMessage"];
    }
}

// Is there flow in the capillary? Scan through the frameBuffer to find out
- (BOOL)computeFlowForBuffer:(FrameBuffer*)frameBuffer
{
    // Output image
    // UIImage* outputImage;
    
    // Movie dimensions
    int rows = 360;
    int cols = 480;
    
    // Algorithm frames
    cv::Mat activeFrame;
    
    // Algorithm parameters
    int interval = 25;
    float max_distance = 2.5;
    int maxFeatures = 500;
    int minHessian = 50;
    float flowThreshold = 0.5;
    
    // Algorithm output accumulators
    float x_motion = 0.0;
    float y_motion = 0.0;
    float abs_motion = 0.0;
    
    // Run through all frames in the frame buffer
    int idx = 0;
    while(idx < frameBuffer.numFrames.intValue) {
        // Optimize the Hessian detector
        if (idx == 0) {
            // Convert the frame to 16 bit unsigned
            activeFrame = [frameBuffer getFrameAtIndex:idx];
            activeFrame.convertTo(activeFrame, CV_16UC1);
            
            // Perform simple motion estimation
            cv::Mat detectActiveFrame, detectLastFrame;
            activeFrame.convertTo(detectActiveFrame, CV_8UC1);
            
            int detected = 5000;
            int attempts = 0;
            while ((detected > maxFeatures) && attempts < 10) {
                // Decrease the sensitivity of the SURF detection
                if (attempts > 0) {
                    minHessian *= 2;
                }
                cv::SurfFeatureDetector detector(minHessian);
                
                std::vector<cv::KeyPoint> keypoints1;
                detector.detect(detectActiveFrame, keypoints1);
                
                cv::SurfDescriptorExtractor extractor;
                cv::Mat descriptors1;
                extractor.compute(detectActiveFrame, keypoints1, descriptors1);
                detected = descriptors1.rows;
                attempts += 1;
            }
            
        }
        
        if (idx % interval == (interval-1)) {
            cv::Mat lastFrame;
            // Convert the active frame to 16 bit unsigned
            activeFrame = [frameBuffer getFrameAtIndex:idx];
            if (idx > interval) {
                lastFrame = [frameBuffer getFrameAtIndex:idx-interval];
            }
            activeFrame.convertTo(activeFrame, CV_16UC1);
            lastFrame.convertTo(lastFrame, CV_16UC1);
            
            // If lastFrame exists, compute the SURF feature flow
            cv::Size s = lastFrame.size();
            if ((s.height == rows) && (s.width == cols)) {
                
                // Perform simple motion estimation
                cv::SurfFeatureDetector detector(minHessian);
                
                cv::Mat detectActiveFrame, detectLastFrame;
                activeFrame.convertTo(detectActiveFrame, CV_8UC1);
                lastFrame.convertTo(detectLastFrame, CV_8UC1);
                
                std::vector<cv::KeyPoint> keypoints1, keypoints2;
                detector.detect(detectActiveFrame, keypoints1);
                detector.detect(detectLastFrame, keypoints2);
                
                cv::SurfDescriptorExtractor extractor;
                cv::Mat descriptors1, descriptors2;
                
                extractor.compute(detectActiveFrame, keypoints1, descriptors1);
                extractor.compute(detectLastFrame, keypoints2, descriptors2);
                
                if ((descriptors1.rows > 0) && (descriptors2.rows > 0)) {
                    cv::FlannBasedMatcher matcher;
                    std::vector<cv::DMatch> matches;
                    matcher.match(descriptors1, descriptors2, matches);
                    
                    std::vector<cv::DMatch> good_matches, final_matches;
                    
                    for (int i = 0; i < descriptors1.rows; i++) {
                        if (matches[i].distance <= max_distance) {
                            good_matches.push_back(matches[i]);
                        }
                    }
                    
                    // Clean matches further
                    for (int i = 0; i < good_matches.size(); i++) {
                        cv::KeyPoint a = keypoints1[good_matches[i].queryIdx];
                        cv::KeyPoint b = keypoints2[good_matches[i].trainIdx];
                        cv::Point2d offset = b.pt - a.pt;
                        if ((std::abs(offset.x) < max_distance) && (std::abs(offset.y) < max_distance)) {
                            final_matches.push_back(good_matches[i]);
                        }
                    }
                    
                    float local_x = 0.0;
                    float local_y = 0.0;
                    float local_abs = 0.0;
                    for (int i = 0; i < final_matches.size(); i++) {
                        cv::KeyPoint a = keypoints1[final_matches[i].queryIdx];
                        cv::KeyPoint b = keypoints2[final_matches[i].trainIdx];
                        cv::Point2d offset = b.pt - a.pt;
                        local_x += offset.x;
                        local_y += offset.y;
                        
                        local_abs += sqrtf(offset.x*offset.x + offset.y*offset.y);
                    }
                    
                    x_motion += local_x/final_matches.size();
                    y_motion += local_y/final_matches.size();
                    abs_motion += local_abs/final_matches.size();
                    
                    //-- Draw only "good" matches
                    cv::Mat img_matches;
                    
                    for (int i = 0; i < final_matches.size(); i++) {
                        cv::Scalar color(0, 255, 0);
                        cv::line(detectActiveFrame, keypoints1[final_matches[i].queryIdx].pt, keypoints2[final_matches[i].trainIdx].pt, color, 1, 8, 0);
                    }
                    
                    // Output image. Debugging MHB.
                    /*
                    cv::Mat cvOutput;
                    detectActiveFrame.convertTo(cvOutput, CV_8UC1);
                    outputImage = [UIImage imageWithCVMat:cvOutput];
                     */
                }
            }
        }
        
        // Move to the next frame
        idx += 1;
        
    }
    
    float flow = sqrtf(y_motion*y_motion);
    if (flow > flowThreshold) {
        return YES;
    }
    else {
        return NO;
    }
}

-(cv::vector <cv::Point>) getLocalMaxima:(const cv::Mat) src:(int) matchingSize: (int) threshold: (int) gaussKernel:(int) starti :(int) endi
{
    cv::vector <cv::Point> vMaxLoc(0);
    vMaxLoc.reserve(100); // Reserve place for fast access
    cv::Mat processImg = src.clone();
    int w = src.cols;
    int h = src.rows;
    int searchWidth  = w - matchingSize;
    int searchHeight = h - matchingSize;
    int matchingSquareCenter = matchingSize/2;
    if(gaussKernel > 1) // If You need a smoothing
    {
        GaussianBlur(processImg,processImg,cv::Size(gaussKernel,gaussKernel),0,0,4);
    }
    uchar* pProcess = (uchar *) processImg.data; // The pointer to image Data
    int shift = matchingSquareCenter * ( w + 1);
    int k = 0;
    for(int y=0; y < searchHeight; ++y)
    {
        int m = k + shift;
        for(int x=0;x < searchWidth ; ++x)
        {
            if (pProcess[m++] >= threshold)
            {
                cv::Point locMax;
                cv::Mat mROI(processImg, cv::Rect(x,y,matchingSize,matchingSize));
                minMaxLoc(mROI,NULL,NULL,NULL,&locMax);
                if (locMax.x == matchingSquareCenter && locMax.y == matchingSquareCenter)
                {
                    vMaxLoc.push_back(cv::Point( x+locMax.x,y + locMax.y ));
                    int xi=x+locMax.x;
                    int yi= y+locMax.y;
                    // Disable motion detection
                    // Float32 val=flowAngThresh.at<Float32>(yi, xi);
                    // if (val==1){
                    // Add worm to the results dictionary
                    
                    NSMutableDictionary* worm = [[NSMutableDictionary alloc] init];
                    [worm setObject:[NSNumber numberWithInt:xi] forKey:@"x"];
                    [worm setObject:[NSNumber numberWithInt:yi] forKey:@"y"];
                    [worm setObject:[NSNumber numberWithInt:starti] forKey:@"start"];
                    [worm setObject:[NSNumber numberWithInt:endi] forKey:@"end"];
                    
                    [wormObjects addObject:worm];
                    numWorms = numWorms+1;
                }
            }
        }
        k += w;
    }
    return vMaxLoc;
}


@end
