
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
            NSNumber* surfMotionMetric = [resultsDict objectForKey:@"surfMotionMetric"];
            
            [userInfo setObject:motionObjects forKey:@"MotionObjects"];
            [userInfo setObject:[NSNumber numberWithFloat:averageCount] forKey:@"AverageCount"];
            [userInfo setObject:surfMotionMetric forKey:@"SurfMotionMetric"];
        }
        else {
            [userInfo setObject:errorString forKey:@"ErrorString"];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"eventAnalysisComplete" object:self userInfo:userInfo];
    });
}

- (void)processFramesForMovie:(FrameBuffer*) frameBuffer {
    // Parameter space!!! MHB MD
    float bubbleLimit = 480*360*0.3;
    // Algorithm parameters
    int framesToAvg = 7;
    int framesToSkip = 1;
    int avgFrames = framesToAvg/framesToSkip;
    int frameIdx = 0;
    int bubbleThresh=210; //above this threshold, bubbles are identified
    int backgroundSize=50; //these are the kernel sizes used to estimate the background
    int backgroundSize2=75;
    int backgroundSize3=75;
    int backgroundSize4=75;
    int backgroundSize5=75;
    int gaussKernel00=5; //kernel size used for blurring
    int minBack=15; //this is the max val that the background can climb to
    int maxBack=36;
    double backValCorr=2; //multiplier for detected background level. happens AFTER minBack is capped
    int corrGausSize=31; //these are used to generate the correlation gaussian
    int corrGausSig=100;
    int thresh=1; //the minimum value of the local maxima
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
    
    //calculate intensity normalizing matrix
    frameIdx = 0;
    while(frameIdx < (frameBuffer.numFrames.integerValue)) {
        movieFrameMat = [frameBuffer getFrameAtIndex:frameIdx];
        
        // Output image. Debugging MHB.
        cv::Mat cvOutput;
        movieFrameMat.convertTo(cvOutput, CV_8UC1);
        UIImage* outputImage = [UIImage imageWithCVMat:cvOutput];
        
        //calc the illum uniformity
        if (frameIdx==0){
            //identify white areas
            threshold(movieFrameMat, movieFrameMatBW, bubbleThresh, 255, CV_THRESH_BINARY);
            int blurKernel=15;
            int dilationKernel=7;
            cv::Mat element = getStructuringElement(CV_SHAPE_ELLIPSE, cv::Size(dilationKernel,dilationKernel ), cv::Point( (dilationKernel-1)/(dilationKernel-1), 2 ));
            cv::morphologyEx(movieFrameMatBW,movieFrameMatBW, CV_MOP_DILATE, element );
            movieFrameMatBWInv =  cv::Scalar::all(255) - movieFrameMatBW.clone();
            movieFrameMatBW.convertTo(movieFrameMatBW, CV_32FC1);
            movieFrameMatBW=movieFrameMatBW*255;
            movieFrameMatBWInv.convertTo(movieFrameMatBWInv, CV_32FC1);
            movieFrameMatBWInv=movieFrameMatBWInv/255;
            
            //general illum normalizer
            movieFrameMatIllum=movieFrameMat.clone();
            movieFrameMatIllum.convertTo(movieFrameMatIllum, CV_32FC1);
            
            cv::Mat blurCorrection=movieFrameMatBWInv.clone();
            cv::blur(blurCorrection,blurCorrection,cv::Size(blurKernel,blurKernel));
            for (int blurCycle=0; blurCycle<5; blurCycle++){
                cv::multiply(movieFrameMatIllum, movieFrameMatBWInv, movieFrameMatIllum);
                cv::blur(movieFrameMatIllum,movieFrameMatIllum,cv::Size(blurKernel,blurKernel));
                cv::divide(movieFrameMatIllum, blurCorrection, movieFrameMatIllum);
            }
            double minVal;
            double maxVal;
            cv::minMaxLoc(movieFrameMatIllum, &minVal, &maxVal);
            cv::divide(movieFrameMatIllum, maxVal, movieFrameMatIllum);
            cv::multiply(movieFrameMatIllum, movieFrameMatBWInv, movieFrameMatIllum);
            
            //reset white pixels to 1
            cv::Mat matBW=movieFrameMatBW/(255*255);
            cv::add(movieFrameMatIllum, matBW, movieFrameMatIllum);
            
            // Output image. Debugging MHB.
            movieFrameMatIllum= cv::Mat::ones(rows,cols,CV_32FC1);
            cv::Mat cvOutput;
            cvOutput = movieFrameMatIllum.clone();
            cvOutput *= 255;
            cvOutput.convertTo(cvOutput, CV_8UC1);
            UIImage* outputImage = [UIImage imageWithCVMat:cvOutput];
        }
        frameIdx=frameIdx+1;
    }
    
    int i = 0;
    frameIdx = 0;
    // Compute difference image from current movie
    while(frameIdx < (frameBuffer.numFrames.integerValue)) {
        while(i < avgFrames) {
            int bufferIdx = frameIdx;
            //read the image and do illum correction
            movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
            movieFrameMat.convertTo(movieFrameMat, CV_32FC1);
            cv::divide(movieFrameMat,movieFrameMatIllum,movieFrameMat);
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
            //do illum correction on the next frame
            movieFrameMat.convertTo(movieFrameMat, CV_32FC1);
            cv::divide(movieFrameMat,movieFrameMatIllum,movieFrameMat);
            cv::multiply(movieFrameMat,movieFrameMatBWInv,movieFrameMat);
            movieFrameMat.convertTo(movieFrameMat, CV_16UC1);
            
            int firstBufferIdx = (frameIdx-avgFrames);
            movieFrameMatFirst = [frameBuffer getFrameAtIndex:firstBufferIdx];
            /*cv::Mat uiOutput;
             movieFrameMatFirst.convertTo(uiOutput, CV_8UC1);
             UIImage* outputImage = [UIImage imageWithCVMat:uiOutput];*/
            //do illum correction on the first frame
            movieFrameMatFirst.convertTo(movieFrameMatFirst, CV_32FC1);
            cv::divide(movieFrameMatFirst,movieFrameMatIllum,movieFrameMatFirst);
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
    
    movieFrameMatDiff1=movieFrameMatDiff1*10;
    movieFrameMatDiff2=movieFrameMatDiff2*10;
    movieFrameMatDiff3=movieFrameMatDiff3*10;
    movieFrameMatDiff4=movieFrameMatDiff4*10;
    movieFrameMatDiff5=movieFrameMatDiff5*10;
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
    
    // Output image. Debugging MHB.
    cv::Mat cvOutput;
    movieFrameMatDiff1.convertTo(cvOutput, CV_8UC1);
    UIImage* outputImage = [UIImage imageWithCVMat:cvOutput];
    
    NSLog(@"done with loop, sums are %f, %f, %f, %f, %f", sum11[0],sum22[0],sum33[0],sum44[0],sum55[0]);
    //estimate background
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
    if (backVal1<minBack) {
        backVal1=minBack;
    }
    else if (backVal1>maxBack) {
        backVal1=maxBack;
    }
    //new background calcs2
    backgroundConvMat= cv::Mat::ones(backgroundSize2,backgroundSize2, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize2*backgroundSize2);
    cv::Mat movieFrameMatDiff2Back=movieFrameMatDiff2+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff2Back, movieFrameMatDiff2Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal2;
    double maxValTrash2;
    cv::minMaxLoc(movieFrameMatDiff2Back, &backVal2, &maxValTrash2);
    if (backVal2<minBack) {
        backVal2=minBack;
    }
    else if (backVal2>maxBack) {
        backVal2=maxBack;
    }
    //new background calcs3
    backgroundConvMat= cv::Mat::ones(backgroundSize3,backgroundSize3, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize3*backgroundSize3);
    cv::Mat movieFrameMatDiff3Back=movieFrameMatDiff3+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff3Back, movieFrameMatDiff3Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal3;
    double maxValTrash3;
    cv::minMaxLoc(movieFrameMatDiff3Back, &backVal3, &maxValTrash3);
    if (backVal3<minBack) {
        backVal3=minBack;
    }
    else if (backVal3>maxBack) {
        backVal3=maxBack;
    }
    //new background calcs4
    backgroundConvMat= cv::Mat::ones(backgroundSize4,backgroundSize4, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize4*backgroundSize4);
    cv::Mat movieFrameMatDiff4Back=movieFrameMatDiff4+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff4Back, movieFrameMatDiff4Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal4;
    double maxValTrash4;
    cv::minMaxLoc(movieFrameMatDiff4Back, &backVal4, &maxValTrash4);
    if (backVal4<minBack) {
        backVal4=minBack;
    }
    else if (backVal4>maxBack) {
        backVal4=maxBack;
    }
    //new background calcs5
    backgroundConvMat= cv::Mat::ones(backgroundSize5,backgroundSize5, CV_32FC1);
    backgroundConvMat=backgroundConvMat/(backgroundSize5*backgroundSize5);
    cv::Mat movieFrameMatDiff5Back=movieFrameMatDiff5+movieFrameMatBW;
    cv::dilate(movieFrameMatDiff5Back, movieFrameMatDiff5Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal5;
    double maxValTrash5;
    cv::minMaxLoc(movieFrameMatDiff5Back, &backVal5, &maxValTrash5);
    if (backVal5<minBack) {
        backVal5=minBack;
    }
    else if (backVal5>maxBack) {
        backVal5=maxBack;
    }
    
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
    
    // Output image. Debugging MHB.
    cvOutput;
    movieFrameMatDiff1.convertTo(cvOutput, CV_8UC1);
    outputImage = [UIImage imageWithCVMat:cvOutput];
    
    //detect features
    cv::SurfFeatureDetector detector(minHessian);
    std::vector<cv::KeyPoint> keypoints;
    detector.detect(movieFrameMatDiff1, keypoints);
    unsigned long numPoints1=keypoints.size();
    detector.detect(movieFrameMatDiff2, keypoints);
    unsigned long numPoints2=keypoints.size();
    detector.detect(movieFrameMatDiff3, keypoints);
    unsigned long numPoints3=keypoints.size();
    detector.detect(movieFrameMatDiff4, keypoints);
    unsigned long numPoints4=keypoints.size();
    detector.detect(movieFrameMatDiff5, keypoints);
    unsigned long numPoints5=keypoints.size();
    NSLog(@"numsurf, %ld,%ld,%ld,%ld,%ld",numPoints1,numPoints2,numPoints3,numPoints4,numPoints5);
    
    //read out total intensity
    cv::Scalar sumDiff1=cv::sum(movieFrameMatDiff1);
    cv::Scalar sumDiff2=cv::sum(movieFrameMatDiff2);
    cv::Scalar sumDiff3=cv::sum(movieFrameMatDiff3);
    cv::Scalar sumDiff4=cv::sum(movieFrameMatDiff4);
    cv::Scalar sumDiff5=cv::sum(movieFrameMatDiff5);
    NSLog(@"diffsums, %f, %f, %f, %f, %f", sumDiff1[0],sumDiff2[0],sumDiff3[0],sumDiff4[0],sumDiff5[0]);
    
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
    [resultsDict setObject:[NSNumber numberWithFloat:0.0] forKey:@"surfMotionMetric"];
    
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
