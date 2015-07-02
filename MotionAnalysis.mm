
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
    threshold(croppedImage, mask, 200, 255, CV_THRESH_BINARY_INV);
    
    //calc the focus metric
    cv::Mat lap;
    cv::Laplacian(croppedImage, lap, CV_64F);
    cv::Scalar mu, sigma;
    cv::meanStdDev(lap, mu, sigma, mask);

    double focusMeasure = sigma.val[0]*sigma.val[0];
    double normFocusMeasure = focusMeasure/100.0;
    
    return normFocusMeasure;
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
            
            [userInfo setObject:motionObjects forKey:@"MotionObjects"];
            [userInfo setObject:[NSNumber numberWithFloat:averageCount] forKey:@"AverageCount"];
        }
        else {
            [userInfo setObject:errorString forKey:@"ErrorString"];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"eventAnalysisComplete" object:self userInfo:userInfo];
    });
}

- (void)processFramesForMovie:(FrameBuffer*) frameBuffer {
    
    // Parameter space!!! MHB MD
    float bubbleLimit = 480*360*0.5;
    
    // Is there flow in the capillary?
    BOOL flow = [self computeFlowForBuffer:frameBuffer];
    NSLog(@"Flow: %@", flow ? @"YES" : @"NO");
    
    // Initialize the wormObjects array
    wormObjects = [[NSMutableArray alloc] init];
    
    numWorms = 0;
    // Start at the first frame
    int frameIdx = 0;
    numWorms=0;
    // Movie dimensions
    int rows = 360;
    int cols = 480;
    // Algorithm parameters
    int framesToAvg = 7;
    int framesToSkip = 1;
    // Focus parameter
    double focusMeasure = 0.0;
    double normFocusMeasure = 0.0;
    // Matrix for storing normalized frames
    cv::Mat movieFrameMatNorm=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm2=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm3=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm4=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm5=cv::Mat::zeros(rows, cols, CV_16UC1);
    // Temporary matrices for image processing
    cv::Mat movieFrameMatOld;
    cv::Mat movieFrameMatCum(rows,cols, CV_16UC1, cv::Scalar::all(0));
    cv::Mat movieFrameMatFirst;
    cv::Mat movieFrameMatDiff= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiffTmp;
    cv::Mat movieFrameMat;
    cv::Mat movieFrameMatLast;
    cv::Mat movieFrameMatIllum;
    cv::Mat movieFrameMatBW;
    cv::Mat movieFrameMatBWInv;
    cv::Mat movieFrameMatBWCopy;
    cv::Mat movieFrameMatDiffOrig;
    cv::Mat movieFrameMatNormOld;
    cv::Mat movieFrameMatDiff1= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff2= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff3= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff4= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiff5= cv::Mat::zeros(rows, cols, CV_16UC1);
    int avgFrames = framesToAvg/framesToSkip;
    frameIdx = 0;
    cv::Mat diffTest=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat movieFrameMatOldTest;
    cv::Mat diffTest1=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest2=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest3=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest4=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest5=cv::Mat::zeros(rows, cols, CV_16UC1);;
    
    int i = 0;
    frameIdx = 0;
    // Compute difference image from current movie
    while(frameIdx < (frameBuffer.numFrames.integerValue)) {
        while(i < avgFrames) {
            int bufferIdx = frameIdx;
            movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
            double backVal;
            double maxValTrash;
            cv::minMaxLoc(movieFrameMat, &backVal, &maxValTrash);
            if (i==0){
                
                threshold(movieFrameMat, movieFrameMatBW, 200, 255, CV_THRESH_BINARY);
                cv::Mat element = getStructuringElement(CV_SHAPE_ELLIPSE, cv::Size( 10,10 ), cv::Point( 2, 2 ));
                cv::morphologyEx(movieFrameMatBW,movieFrameMatBW, CV_MOP_DILATE, element );
                movieFrameMatBWInv =  cv::Scalar::all(255) - movieFrameMatBW.clone();
                movieFrameMatBW.convertTo(movieFrameMatBW, CV_16UC1);
                movieFrameMatBW=movieFrameMatBW*255;
                movieFrameMatBWInv.convertTo(movieFrameMatBWInv, CV_16UC1);
                movieFrameMatBWInv=movieFrameMatBWInv/255;
                movieFrameMatIllum=movieFrameMat.clone();
                movieFrameMatIllum.convertTo(movieFrameMatIllum, CV_16UC1);
                
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
                threshold(croppedImage, mask, 200, 255, CV_THRESH_BINARY_INV);
                //calc the focus metric
                cv::Mat lap;
                cv::Laplacian(croppedImage, lap, CV_64F);
                cv::Scalar mu, sigma;
                cv::meanStdDev(lap, mu, sigma, mask);
                focusMeasure = sigma.val[0]*sigma.val[0];
                normFocusMeasure = focusMeasure/100.0;
            }
            movieFrameMat.convertTo(movieFrameMat, CV_16UC1);
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
            // Grab the current movie from the frame buffer list
            int bufferIdx = frameIdx;
            movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
            // Convert the frame into 16 bit grayscale. Space for optimization
            movieFrameMat.convertTo(movieFrameMat, CV_16UC1);
            // Grab the first frame from the current ave from the frame buffer list
            int firstBufferIdx = (frameIdx-avgFrames+1);
            movieFrameMatFirst = [frameBuffer getFrameAtIndex:firstBufferIdx];
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
    cv::multiply(movieFrameMatDiff1, movieFrameMatBWInv, movieFrameMatDiff1);
    cv::multiply(movieFrameMatDiff2, movieFrameMatBWInv, movieFrameMatDiff2);
    cv::multiply(movieFrameMatDiff3, movieFrameMatBWInv, movieFrameMatDiff3);
    cv::multiply(movieFrameMatDiff4, movieFrameMatBWInv, movieFrameMatDiff4);
    cv::multiply(movieFrameMatDiff5, movieFrameMatBWInv, movieFrameMatDiff5);
    movieFrameMatDiff1=movieFrameMatDiff1*10;
    movieFrameMatDiff2=movieFrameMatDiff2*10;
    movieFrameMatDiff3=movieFrameMatDiff3*10;
    movieFrameMatDiff4=movieFrameMatDiff4*10;
    movieFrameMatDiff5=movieFrameMatDiff5*10;
    int gaussKernel00=5;
    GaussianBlur(movieFrameMatDiff1,movieFrameMatDiff1,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff2,movieFrameMatDiff2,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff3,movieFrameMatDiff3,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff4,movieFrameMatDiff4,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff5,movieFrameMatDiff5,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    cv::Scalar sum11=cv::sum(movieFrameMatDiff1);
    cv::Scalar sum22=cv::sum(movieFrameMatDiff2);
    cv::Scalar sum33=cv::sum(movieFrameMatDiff3);
    cv::Scalar sum44=cv::sum(movieFrameMatDiff4);
    cv::Scalar sum55=cv::sum(movieFrameMatDiff5);
    
    NSLog(@"done with loop, sums are %f, %f, %f, %f, %f", sum11[0],sum22[0],sum33[0],sum44[0],sum55[0]);
    //estimate background
    int backSize=30;
    int backgroundSize=75; //was 75
    int backgroundSize2=75; //was 75
    int backgroundSize3=75; //was 75
    int backgroundSize4=75; //was 75
    int backgroundSize5=75; //was 75
    
    cv::Mat backConvMat= cv::Mat::ones(backSize, backSize, CV_32FC1);
    backConvMat=backConvMat/(backSize*backSize);
    cv::Mat backgroundConvMat= cv::Mat::ones(backgroundSize,backgroundSize, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize*backgroundSize);
    movieFrameMatDiff=movieFrameMatDiff+movieFrameMatBW;
    cv::filter2D(movieFrameMatDiff,movieFrameMatDiff,-1,backgroundConvMat, cv::Point(-1,-1));
    double backVal;
    double maxValTrash;
    cv::minMaxLoc(movieFrameMatDiff, &backVal, &maxValTrash);
    //new background calcs1
    cv::Mat movieFrameMatDiff1Back=movieFrameMatDiff1+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff1Back, movieFrameMatDiff1Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal1;
    double maxValTrash1;
    cv::minMaxLoc(movieFrameMatDiff1Back, &backVal1, &maxValTrash1);
    if (backVal1<12) {
        backVal1=12;
    }
    //new background calcs2
    backgroundConvMat= cv::Mat::ones(backgroundSize2,backgroundSize2, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize2*backgroundSize2);
    cv::Mat movieFrameMatDiff2Back=movieFrameMatDiff2+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff2Back, movieFrameMatDiff2Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal2;
    double maxValTrash2;
    cv::minMaxLoc(movieFrameMatDiff2Back, &backVal2, &maxValTrash2);
    if (backVal2<12) {
        backVal2=12;
    }
    //new background calcs3
    backgroundConvMat= cv::Mat::ones(backgroundSize3,backgroundSize3, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize3*backgroundSize3);
    cv::Mat movieFrameMatDiff3Back=movieFrameMatDiff3+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff3Back, movieFrameMatDiff3Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal3;
    double maxValTrash3;
    cv::minMaxLoc(movieFrameMatDiff3Back, &backVal3, &maxValTrash3);
    if (backVal3<12) {
        backVal3=12;
    }
    //new background calcs4
    backgroundConvMat= cv::Mat::ones(backgroundSize4,backgroundSize4, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize4*backgroundSize4);
    cv::Mat movieFrameMatDiff4Back=movieFrameMatDiff4+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff4Back, movieFrameMatDiff4Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal4;
    double maxValTrash4;
    cv::minMaxLoc(movieFrameMatDiff4Back, &backVal4, &maxValTrash4);
    if (backVal4<12) {
        backVal4=12;
    }
    
    //new background calcs5
    backgroundConvMat= cv::Mat::ones(backgroundSize5,backgroundSize5, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize5*backgroundSize5);
    cv::Mat movieFrameMatDiff5Back=movieFrameMatDiff5+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff5Back, movieFrameMatDiff5Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal5;
    double maxValTrash5;
    cv::minMaxLoc(movieFrameMatDiff5Back, &backVal5, &maxValTrash5);
    if (backVal5<12) {
        backVal5=12;
    }
    double backValCorr=2;
    double backValCorr1=backValCorr;
    double backValCorr2=backValCorr;
    double backValCorr3=backValCorr;
    double backValCorr4=backValCorr;
    double backValCorr5=backValCorr;
    movieFrameMatDiff1=movieFrameMatDiff1-backVal1*backValCorr1;
    movieFrameMatDiff2=movieFrameMatDiff2-backVal2*backValCorr2;
    movieFrameMatDiff3=movieFrameMatDiff3-backVal3*backValCorr3;
    movieFrameMatDiff4=movieFrameMatDiff4-backVal4*backValCorr4;
    movieFrameMatDiff5=movieFrameMatDiff5-backVal5*backValCorr5;
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
    cv::Mat element = getStructuringElement(0, cv::Size( 2*erosionSize + 1, 2*erosionSize+1 ),cv::Point( erosionSize, erosionSize));
    cv::erode( movieFrameMatDiff1, movieFrameMatDiff1, element );
    cv::erode( movieFrameMatDiff2, movieFrameMatDiff2, element );
    cv::erode( movieFrameMatDiff3, movieFrameMatDiff3, element );
    cv::erode( movieFrameMatDiff4, movieFrameMatDiff4, element );
    cv::erode( movieFrameMatDiff5, movieFrameMatDiff5, element );
    int gaussKernel000=5;
    GaussianBlur(movieFrameMatDiff1,movieFrameMatDiff1,cv::Size(gaussKernel000,gaussKernel000),0,0,4);
    GaussianBlur(movieFrameMatDiff2,movieFrameMatDiff2,cv::Size(gaussKernel000,gaussKernel000),0,0,4);
    GaussianBlur(movieFrameMatDiff3,movieFrameMatDiff3,cv::Size(gaussKernel000,gaussKernel000),0,0,4);
    GaussianBlur(movieFrameMatDiff4,movieFrameMatDiff4,cv::Size(gaussKernel000,gaussKernel000),0,0,4);
    GaussianBlur(movieFrameMatDiff5,movieFrameMatDiff5,cv::Size(gaussKernel000,gaussKernel000),0,0,4);
    //convolve with mean subtracted gaussian
    cv::Mat gaussKer0=cv::getGaussianKernel(31, 100, CV_32F ); //was 51
    cv::Mat gaussKer= gaussKer0 * gaussKer0.t();
    cv::Scalar aveGaussKer=cv::mean(gaussKer);
    gaussKer=gaussKer-aveGaussKer[0];
    movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_32F);
    cv::filter2D(movieFrameMatDiff1,movieFrameMatDiff1,-1,gaussKer, cv::Point(-1,-1));
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
    int thresh=1;
    int matchingSize=17;
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
    cv::Scalar highSigSum=cv::sum(movieFrameMatBWInv);
    float totalArea = 480*360;
    float ignoredArea = 480*360 - highSigSum[0];
    numWorms=numWorms*(totalArea/(totalArea-ignoredArea));
    NSLog(@"numWorms %f", numWorms);
    movieFrameMatDiff.release();
    movieFrameMatDiff1.release();
    movieFrameMatDiff2.release();
    movieFrameMatDiff3.release();
    movieFrameMatDiff4.release();
    movieFrameMatDiff5.release();
    movieFrameMatBW.release();
    
    [resultsDict setObject:wormObjects forKey:@"MotionObjects"];
    [resultsDict setObject:[NSNumber numberWithFloat:normFocusMeasure] forKey:@"FocusMetric"];
    NSLog(@"NormFocusValue: %f", normFocusMeasure);
    
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
    UIImage* outputImage;
    
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
    float flowThreshold = 0.35;
    
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
                printf("Detected: %d\n", detected);
                attempts += 1;
            }
            printf("Hessian: %d\n", minHessian);
            
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
                    
                    cv::Mat cvOutput;
                    detectActiveFrame.convertTo(cvOutput, CV_8UC1);
                    outputImage = [UIImage imageWithCVMat:cvOutput];
                }
            }
        }
        
        // Move to the next frame
        idx += 1;
        
    }
    
    float flow = sqrtf(y_motion*y_motion);
    printf("Flow parameter: %f\n", flow);
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
                    numWorms=numWorms+1;
                    
                    // }
                    // else {
                    //     NSLog(@"point rejected due to motion");
                    // }
                }
            }
        }
        k += w;
    }
    return vMaxLoc;
}


@end
