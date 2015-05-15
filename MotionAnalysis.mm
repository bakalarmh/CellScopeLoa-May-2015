
//
//  MotionAnalysis.m
//  CellScopeLoa

#import "MotionAnalysis.h"
#import "UIImage+OpenCV.h"
#import "ProcessingResults.h"
#import "FrameBuffer.h"

@implementation MotionAnalysis {
    NSMutableArray* movieLengths;
    NSInteger movieIdx;
    NSInteger frameIdx;
    NSInteger numFramesMax;
    NSInteger numMovies;
    float sensitivity;
    double progress;
    double numWorms;
    
    dispatch_queue_t backgroundQueue;
}

@synthesize coordsArray;
@synthesize resultsList;
@synthesize frameBufferList;

-(id)initWithWidth:(NSInteger)width Height:(NSInteger)height
            Frames:(NSInteger)frames
            Movies:(NSInteger)movies
       Sensitivity: (float) sense {
    
    self = [super init];
    
    progress = 0.0;
    
    movieIdx = 0;
    frameIdx = 0;
    numFramesMax = frames;
    numMovies = movies;
    sensitivity = sense;
    coordsArray = [[NSMutableArray alloc] init];
    movieLengths = [[NSMutableArray alloc] init];
    
    // MHB properties
    frameBufferList = [[NSMutableArray alloc] init];
    resultsList = [[NSMutableArray alloc] init];
    backgroundQueue = dispatch_queue_create("com.cellscopeloa.analysis.bgqueue", NULL);
    
    return self;
}

- (void)processFrameBuffer:(FrameBuffer*)frameBuffer withSerial:(NSString *)serial
{
    [frameBufferList addObject:frameBuffer];
    dispatch_async(backgroundQueue, ^(void) {
        // Pop the latest frame buffer off of the stack
        FrameBuffer* localFrameBuffer = [frameBufferList objectAtIndex:(frameBufferList.count-1)];
        [frameBufferList removeLastObject];
        
        ProcessingResults* results = [[ProcessingResults alloc] initWithFrameBuffer:localFrameBuffer andSerial:serial];
        NSMutableArray* coordinates = [self processFramesForMovie:localFrameBuffer];
        for (int idx=0; idx+3<[coordinates count]; idx=idx+4){
            
            NSNumber* pointx= [coordinates objectAtIndex:(NSInteger)idx];
            NSNumber* pointy= [coordinates objectAtIndex:(NSInteger)idx+1];
            
            CGPoint point=CGPointMake([pointx floatValue], [pointy floatValue]);
            NSNumber* start= [coordinates objectAtIndex:(NSInteger)idx+2];
            NSNumber* end= [coordinates objectAtIndex:(NSInteger)idx+3];
            NSLog(@"pointx pointy start end %@ %@ %@ %@", pointx, pointy, start, end);
            
            [results addPoint:point from:[start integerValue] to:[end integerValue]];
        }
        NSLog(@"Results!! %d", results.points.count);
        // Add results to the list and free the frame buffer
        [resultsList addObject:results];
        [localFrameBuffer releaseFrameBuffers];
        // Free analysis resources
        [coordsArray removeAllObjects];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FrameBufferProcessed" object:nil];
    });
}

- (NSMutableArray *)processFramesForMovie:(FrameBuffer*) frameBuffer {
    numWorms = 0;
    // Start at the first frame
    frameIdx = 0;
    //coordsArray = [[NSMutableArray alloc] init];
    numWorms=0;
    movieIdx = 0;
    //NSNumber *movielength = [movieLengths objectAtIndex:0];
    NSInteger numFrames = frameBuffer.numFrames.integerValue;
    
    // Movie dimensions
    int rows = 360;
    int cols = 480;
    //int sz[3] = {rows,cols,3};
    
    // Algorithm parameters
    int framesToAvg = 7;
    int framesToSkip = 1;
    // Matrix for storing normalized frames
    cv::Mat movieFrameMatNorm=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm2=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm3=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm4=cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatNorm5=cv::Mat::zeros(rows, cols, CV_16UC1);
    
    // Temporary matrices for image processing
    cv::Mat movieFrameMatOld;
    cv::Mat movieFrameMatCum(rows,cols, CV_16UC1, cv::Scalar::all(0));
    /*cv::Mat movieFrameMatCum2(rows,cols, CV_16UC1, cv::Scalar::all(0));
     cv::Mat movieFrameMatCum3(rows,cols, CV_16UC1, cv::Scalar::all(0));
     cv::Mat movieFrameMatCum4(rows,cols, CV_16UC1, cv::Scalar::all(0));
     cv::Mat movieFrameMatCum5(rows,cols, CV_16UC1, cv::Scalar::all(0));*/
    
    cv::Mat movieFrameMatFirst;
    /*cv::Mat movieFrameMatSecond;
     cv::Mat movieFrameMatThird;
     cv::Mat movieFrameMatFourth;
     cv::Mat movieFrameMatFifth;*/
    
    
    cv::Mat movieFrameMatDiff= cv::Mat::zeros(rows, cols, CV_16UC1);
    cv::Mat movieFrameMatDiffTmp;
    /*cv::Mat movieFrameMatDiffTmp2;
     cv::Mat movieFrameMatDiffTmp3;
     cv::Mat movieFrameMatDiffTmp4;
     cv::Mat movieFrameMatDiffTmp5;*/
    
    cv::Mat movieFrameMat;
    /*cv::Mat movieFrameMat2;
     cv::Mat movieFrameMat3;
     cv::Mat movieFrameMat4;
     cv::Mat movieFrameMat5;*/
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
    int initBlurKernel=5;
    double flicker1=0;
    double flicker2=0;
    double flicker3=0;
    double flicker4=0;
    double flicker5=0;
    int framesBetweenDiff=1;
    int i = 0;
    int avgFrames = framesToAvg/framesToSkip;
    frameIdx = 0;
    int sumSum=0;
    cv::Mat diffTest=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat movieFrameMatOldTest;
    cv::Mat diffTest1=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest2=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest3=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest4=cv::Mat::zeros(rows, cols, CV_16UC1);;
    cv::Mat diffTest5=cv::Mat::zeros(rows, cols, CV_16UC1);;
    
    while(frameIdx < ((frameBuffer.numFrames.integerValue))) {
        
        int bufferIdx = movieIdx*numFramesMax + (frameIdx);
        movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
        //GaussianBlur(movieFrameMat,movieFrameMat,cv::Size(initBlurKernel,initBlurKernel),0,0,4);
        cv::Scalar sum=cv::sum(movieFrameMat);
        sumSum=sumSum+sum[0];
        double backVal;
        double maxValTrash;
        cv::minMaxLoc(movieFrameMat, &backVal, &maxValTrash);
        frameIdx++;
    }
    double aveSum=sumSum/frameIdx;
    i = 0;
    frameIdx = 0;
    double flickerLow=.7;
    double flickerHigh=1.3;
    double focusMeasure;
    double focusMeasure2;
    
    // Compute difference image from current movie
    while(frameIdx < (frameBuffer.numFrames.integerValue)) {
        //[self setProgressWithMovie:movidx Frame:frameIdx];
        while(i < avgFrames) {
            // Update the progress bar
            //[self setProgressWithMovie:movidx Frame:frameIdx];
            // Grab the current movie from the frame buffer list
            int bufferIdx = movieIdx*numFramesMax + (frameIdx);
            //NSLog(@"bufferidxinit: %i", bufferIdx);
            //NSLog(@"frameidx is %i, ", frameIdx);
            movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
            cv::Scalar sum=cv::sum(movieFrameMat);
            movieFrameMat=movieFrameMat*(aveSum/sum[0]);
            if (aveSum/sum[0]>flickerHigh || aveSum/sum[0]<flickerLow) {
                flicker1++;
            }
            double backVal;
            double maxValTrash;
            cv::minMaxLoc(movieFrameMat, &backVal, &maxValTrash);
            if (i==0){
                threshold(movieFrameMat, movieFrameMatBW,150, 255, CV_THRESH_BINARY);
                //threshold(movieFrameMat, movieFrameMatBWInv, 30, 1, CV_THRESH_BINARY);
                
                cv::Mat element = getStructuringElement(CV_SHAPE_ELLIPSE, cv::Size( 10,10 ), cv::Point( 2, 2 ));
                cv::morphologyEx(movieFrameMatBW,movieFrameMatBW, CV_MOP_DILATE, element );
                //cv::Mat movieFrameMatBWInv;
                //cv::subtract(cv::Scalar::all(255),movieFrameMatBW, movieFrameMatBWInv);
                movieFrameMatBWInv =  cv::Scalar::all(255) - movieFrameMatBW.clone();
                
                movieFrameMatBW.convertTo(movieFrameMatBW, CV_16UC1);
                movieFrameMatBW=movieFrameMatBW*255;
                
                movieFrameMatBWInv.convertTo(movieFrameMatBWInv, CV_16UC1);
                movieFrameMatBWInv=movieFrameMatBWInv/255;
                
                movieFrameMatIllum=movieFrameMat.clone();
                movieFrameMatIllum.convertTo(movieFrameMatIllum, CV_16UC1);
                
                cv::Rect myROI(100, 100, 200, 200);
                cv::Mat croppedImage = movieFrameMat(myROI);
                cv::Mat lap;
                cv::Laplacian(croppedImage, lap, CV_64F);
                cv::Scalar mu, sigma;
                cv::meanStdDev(lap, mu, sigma);
                focusMeasure = sigma.val[0]*sigma.val[0];
                NSLog(@"focus measure is, %f", focusMeasure);
                int ksize=5;
                cv::Mat Gx, Gy;
                cv::Sobel(croppedImage, Gx, CV_64F, 1, 0, ksize);
                cv::Sobel(croppedImage, Gy, CV_64F, 0, 1, ksize);
                cv::Mat FM = Gx.mul(Gx) + Gy.mul(Gy);
                focusMeasure2 = cv::mean(FM).val[0];
                NSLog(@"focus measure2 is, %f", focusMeasure2);
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
            int bufferIdx = movieIdx*numFramesMax + (frameIdx);
            //NSLog(@"frameidx is %i, ", frameIdx);
            movieFrameMat = [frameBuffer getFrameAtIndex:bufferIdx];
            cv::Scalar sum=cv::sum(movieFrameMat);
            movieFrameMat=movieFrameMat*(aveSum/sum[0]);
            
            // Convert the frame into 16 bit grayscale. Space for optimization
            movieFrameMat.convertTo(movieFrameMat, CV_16UC1);
            
            /*movieFrameMat2 = [frameBuffer getFrameAtIndex:bufferIdx+1];
             cv::Scalar sum2=cv::sum(movieFrameMat2);
             movieFrameMat2=movieFrameMat2*(aveSum/sum2[0]);
             movieFrameMat2.convertTo(movieFrameMat2, CV_16UC1);
             
             movieFrameMat3 = [frameBuffer getFrameAtIndex:bufferIdx+2];
             cv::Scalar sum3=cv::sum(movieFrameMat3);
             movieFrameMat3=movieFrameMat3*(aveSum/sum3[0]);
             movieFrameMat3.convertTo(movieFrameMat3, CV_16UC1);
             
             movieFrameMat4 = [frameBuffer getFrameAtIndex:bufferIdx+3];
             cv::Scalar sum4=cv::sum(movieFrameMat4);
             movieFrameMat4=movieFrameMat4*(aveSum/sum4[0]);
             movieFrameMat4.convertTo(movieFrameMat4, CV_16UC1);
             
             movieFrameMat5 = [frameBuffer getFrameAtIndex:bufferIdx+4];
             cv::Scalar sum5=cv::sum(movieFrameMat5);
             movieFrameMat5=movieFrameMat5*(aveSum/sum5[0]);
             movieFrameMat5.convertTo(movieFrameMat5, CV_16UC1);*/
            
            // Grab the first frame from the current ave from the frame buffer list
            int firstBufferIdx = movieIdx*numFramesMax + (frameIdx-avgFrames+1);
            //NSLog(@"bufferidxfirst: %i", bufferIdx);
            
            movieFrameMatFirst = [frameBuffer getFrameAtIndex:firstBufferIdx];
            movieFrameMatFirst.convertTo(movieFrameMatFirst, CV_16UC1);
            
            /*movieFrameMatSecond = [frameBuffer getFrameAtIndex:firstBufferIdx+1];
             movieFrameMatSecond.convertTo(movieFrameMatSecond, CV_16UC1);
             
             movieFrameMatThird = [frameBuffer getFrameAtIndex:firstBufferIdx+2];
             movieFrameMatThird.convertTo(movieFrameMatThird, CV_16UC1);
             
             movieFrameMatFourth = [frameBuffer getFrameAtIndex:firstBufferIdx+3];
             movieFrameMatFourth.convertTo(movieFrameMatFourth, CV_16UC1);
             
             movieFrameMatFifth = [frameBuffer getFrameAtIndex:firstBufferIdx+4];
             movieFrameMatFifth.convertTo(movieFrameMatFifth, CV_16UC1);*/
            
            movieFrameMatCum = movieFrameMatCum - movieFrameMatFirst + movieFrameMat;
            /*movieFrameMatCum2=movieFrameMatCum - movieFrameMatSecond + movieFrameMat2;
             movieFrameMatCum3=movieFrameMatCum2 - movieFrameMatThird + movieFrameMat3;
             movieFrameMatCum4=movieFrameMatCum3 - movieFrameMatFourth + movieFrameMat4;
             movieFrameMatCum5=movieFrameMatCum4 - movieFrameMatFifth + movieFrameMat5;*/
            
            movieFrameMat.release();
            movieFrameMat=cv::Mat();
            movieFrameMatFirst.release();
            movieFrameMatFirst=cv::Mat();
            
            cv::divide(movieFrameMatCum, avgFrames, movieFrameMatNorm);
            /*cv::divide(movieFrameMatCum2, avgFrames, movieFrameMatNorm2);
             cv::divide(movieFrameMatCum3, avgFrames, movieFrameMatNorm3);
             cv::divide(movieFrameMatCum4, avgFrames, movieFrameMatNorm4);
             cv::divide(movieFrameMatCum5, avgFrames, movieFrameMatNorm5);*/
            
            cv::absdiff(movieFrameMatNormOld, movieFrameMatNorm, movieFrameMatDiffTmp);
            /*cv::absdiff(movieFrameMatNormOld, movieFrameMatNorm2, movieFrameMatDiffTmp2);
             cv::absdiff(movieFrameMatNormOld, movieFrameMatNorm3, movieFrameMatDiffTmp3);
             cv::absdiff(movieFrameMatNormOld, movieFrameMatNorm4, movieFrameMatDiffTmp4);
             cv::absdiff(movieFrameMatNormOld, movieFrameMatNorm5, movieFrameMatDiffTmp5);*/
            
            movieFrameMatNormOld.release();
            movieFrameMatNormOld=cv::Mat();
            
            //movieFrameMatDiffTmp=movieFrameMatDiffTmp+movieFrameMatDiffTmp2;
            //movieFrameMatDiffTmp=movieFrameMatDiffTmp3+movieFrameMatDiffTmp4+movieFrameMatDiffTmp5;
            //movieFrameMatDiffTmp=movieFrameMatDiffTmp;
            
            //cv::Scalar aveDiffTmp=cv::mean(movieFrameMatDiffTmp);
            //if (aveDiffTmp[0]<1) {
            //movieFrameMatDiffTmp= movieFrameMatDiffTmp + movieFrameMatDiffTmp2;
            //    NSLog(@"avedifftmp is %f,", aveDiffTmp[0]);
            
            /*}
             else {
             NSLog(@"big diff ignored!!!!");
             
             }*/
            if (i<=34) {
                movieFrameMatDiff1 = movieFrameMatDiff1 + movieFrameMatDiffTmp;
                //NSLog(@"add to 1");
                if (aveSum/sum[0]>flickerHigh || aveSum/sum[0]<flickerLow) {
                    flicker1++;
                    NSLog(@"flicker1 fired! %f,",flicker1);
                }
            }
            else if  (i<=62) {
                movieFrameMatDiff2 = movieFrameMatDiff2 + movieFrameMatDiffTmp;
                //NSLog(@"add to 2");
                if (aveSum/sum[0]>flickerHigh || aveSum/sum[0]<flickerLow) {
                    flicker2++;
                    NSLog(@"flicker2 fired! %f,",flicker2);
                }
            }
            else if (i<=90) {
                movieFrameMatDiff3 = movieFrameMatDiff3 + movieFrameMatDiffTmp;
                //NSLog(@"add to 3");
                if (aveSum/sum[0]>flickerHigh || aveSum/sum[0]<flickerLow) {
                    flicker3++;
                    NSLog(@"flicker3 fired! %f,",flicker3);
                }
            }
            else if (i<=118) {
                movieFrameMatDiff4 = movieFrameMatDiff4 + movieFrameMatDiffTmp;
                //NSLog(@"add to 4");
                if (aveSum/sum[0]>flickerHigh || aveSum/sum[0]<flickerLow) {
                    flicker4++;
                    NSLog(@"flicker4 fired! %f,",flicker4);
                }
            }
            else if (i<=146) {
                movieFrameMatDiff5 = movieFrameMatDiff5 + movieFrameMatDiffTmp;
                // NSLog(@"add to 5");
                if (aveSum/sum[0]>flickerHigh || aveSum/sum[0]<flickerLow) {
                    flicker5++;
                    NSLog(@"flicker5 fired! %f,",flicker5);
                }
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
    
    //movieFrameMatDiff1=movieFrameMatDiff1*movieFrameMatBWInv;
    //movieFrameMatDiff2=movieFrameMatDiff2*movieFrameMatBWInv;
    //movieFrameMatDiff3=movieFrameMatDiff3*movieFrameMatBWInv;
    //movieFrameMatDiff4=movieFrameMatDiff4*movieFrameMatBWInv;
    //movieFrameMatDiff5=movieFrameMatDiff5*movieFrameMatBWInv;
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
    
    //denoising block
    /*movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_8UC1);
     movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_8UC1);
     movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_8UC1);
     movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_8UC1);
     movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_8UC1);
     cv::fastNlMeansDenoising(movieFrameMatDiff1, movieFrameMatDiff1, 10 ,7, 21);
     cv::fastNlMeansDenoising(movieFrameMatDiff2, movieFrameMatDiff2, 10 ,7, 21);
     cv::fastNlMeansDenoising(movieFrameMatDiff3, movieFrameMatDiff3, 10 ,7, 21);
     cv::fastNlMeansDenoising(movieFrameMatDiff4, movieFrameMatDiff4, 10 ,7, 21);
     cv::fastNlMeansDenoising(movieFrameMatDiff5, movieFrameMatDiff5, 10 ,7, 21);
     movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_16UC1);
     movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_16UC1);
     movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_16UC1);
     movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_16UC1);
     movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_16UC1);*/
    
    //if you want to do floating point calcs...
    /*movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_32F);
     movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_32F);
     movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_32F);
     movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_32F);
     movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_32F);*/
    
    int gaussKernel00=5;
    GaussianBlur(movieFrameMatDiff1,movieFrameMatDiff1,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff2,movieFrameMatDiff2,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff3,movieFrameMatDiff3,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff4,movieFrameMatDiff4,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    GaussianBlur(movieFrameMatDiff5,movieFrameMatDiff5,cv::Size(gaussKernel00,gaussKernel00),0,0,4);
    
    //imagewriting
    /*UIImage * testui;
     cv::Mat test=movieFrameMatDiff1.clone();
     test.convertTo(test, CV_8UC1);
     testui = [[UIImage alloc] initWithCVMat:test];
     UIImageWriteToSavedPhotosAlbum(testui,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    //imagewriting
    
    //UIImage * testui;
    /*test=movieFrameMatDiff2.clone();
     test.convertTo(test, CV_8UC1);
     testui = [[UIImage alloc] initWithCVMat:test];
     UIImageWriteToSavedPhotosAlbum(testui,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    
    //imagewriting
    //UIImage * testui;
    /*test=movieFrameMatDiff3.clone();
     test.convertTo(test, CV_8UC1);
     testui = [[UIImage alloc] initWithCVMat:test];
     UIImageWriteToSavedPhotosAlbum(testui,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    //imagewriting
    //UIImage * testui;
    /*test=movieFrameMatDiff4.clone();
     test.convertTo(test, CV_8UC1);
     testui = [[UIImage alloc] initWithCVMat:test];
     UIImageWriteToSavedPhotosAlbum(testui,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    
    //imagewriting
    //UIImage * testui;
    /*test=movieFrameMatDiff5.clone();
     test.convertTo(test, CV_8UC1);
     testui = [[UIImage alloc] initWithCVMat:test];
     UIImageWriteToSavedPhotosAlbum(testui,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    cv::Scalar sum11=cv::sum(movieFrameMatDiff1);
    cv::Scalar sum22=cv::sum(movieFrameMatDiff2);
    cv::Scalar sum33=cv::sum(movieFrameMatDiff3);
    cv::Scalar sum44=cv::sum(movieFrameMatDiff4);
    cv::Scalar sum55=cv::sum(movieFrameMatDiff5);
    
    NSLog(@"done with loop, sums are %f, %f, %f, %f, %f", sum11[0],sum22[0],sum33[0],sum44[0],sum55[0]);
    
    //estimate background
    int backSize=30;
    int backgroundSize=75; //was 75
    
    if (sum11[0]>4000000 || sum22[0] >4000000 || sum33[0]>4000000 || sum44[0] >4000000|| sum55[0]>4000000) {
        backgroundSize=50;
        NSLog(@"lower background");
    }
    if (sum11[0]>4500000 || sum22[0] >4500000 || sum33[0]>4500000 || sum44[0] >4500000|| sum55[0]>4500000) {
        backgroundSize=35;
        NSLog(@"lower background");
    }
    
    cv::Mat backConvMat= cv::Mat::ones(backSize, backSize, CV_32FC1);
    cv::Mat backgroundConvMat= cv::Mat::ones(backgroundSize,backgroundSize, CV_32FC1);
    backConvMat=backConvMat/(backSize*backSize);
    backgroundConvMat=backgroundConvMat/(backgroundSize*backgroundSize);
    
    cv::Scalar sum=cv::sum(movieFrameMatDiff);
    //NSLog(@"sum is %f", sum[0]);
    movieFrameMatDiff=movieFrameMatDiff+movieFrameMatBW;
    cv::filter2D(movieFrameMatDiff,movieFrameMatDiff,-1,backgroundConvMat, cv::Point(-1,-1));
    double backVal;
    double maxValTrash;
    cv::minMaxLoc(movieFrameMatDiff, &backVal, &maxValTrash);
    
    //movieFrameMatBW.convertTo(movieFrameMatBW, CV_32F);
    //new background calcs1
    cv::Scalar sum1=cv::sum(movieFrameMatDiff1);
    NSLog(@"sum1 is %f", sum1[0]);
    cv::Mat movieFrameMatDiff1Back=movieFrameMatDiff1+movieFrameMatBW;
    //cv::filter2D(movieFrameMatDiff1Back,movieFrameMatDiff1Back,-1,backgroundConvMat, cv::Point(-1,-1));
    cv::dilate(movieFrameMatDiff1Back, movieFrameMatDiff1Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal1;
    double maxValTrash1;
    cv::minMaxLoc(movieFrameMatDiff1Back, &backVal1, &maxValTrash1);
    NSLog(@"movieframediff1back min, max is, %f, %f", backVal1, maxValTrash1 );
    cv::Scalar sumt1=cv::sum(movieFrameMatDiff1-backVal1);
    NSLog(@"sumt1 is %f", sumt1[0]);
    
    //new background calcs2
    cv::Scalar sum2=cv::sum(movieFrameMatDiff2);
    NSLog(@"sum2 is %f", sum2[0]);
    cv::Mat movieFrameMatDiff2Back=movieFrameMatDiff2+movieFrameMatBW;
    //cv::filter2D(movieFrameMatDiff2Back,movieFrameMatDiff2Back,-1,backgroundConvMat, cv::Point(-1,-1));
    cv::dilate(movieFrameMatDiff2Back, movieFrameMatDiff2Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal2;
    double maxValTrash2;
    cv::minMaxLoc(movieFrameMatDiff2Back, &backVal2, &maxValTrash2);
    cv::Scalar sumt2=cv::sum(movieFrameMatDiff2-backVal2);
    NSLog(@"sumt2 is %f", sumt2[0]);
    
    //new background calcs3
    cv::Scalar sum3=cv::sum(movieFrameMatDiff3);
    NSLog(@"sum3 is %f", sum3[0]);
    cv::Mat movieFrameMatDiff3Back=movieFrameMatDiff3+movieFrameMatBW;
    //cv::filter2D(movieFrameMatDiff3Back,movieFrameMatDiff3Back,-1,backgroundConvMat, cv::Point(-1,-1));
    cv::dilate(movieFrameMatDiff3Back, movieFrameMatDiff3Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal3;
    double maxValTrash3;
    cv::minMaxLoc(movieFrameMatDiff3Back, &backVal3, &maxValTrash3);
    cv::Scalar sumt3=cv::sum(movieFrameMatDiff3-backVal3);
    NSLog(@"sumt3 is %f", sumt3[0]);
    
    //new background calcs4
    cv::Scalar sum4=cv::sum(movieFrameMatDiff4);
    NSLog(@"sum4 is %f", sum4[0]);
    cv::Mat movieFrameMatDiff4Back=movieFrameMatDiff4+movieFrameMatBW;
    //cv::filter2D(movieFrameMatDiff4Back,movieFrameMatDiff4Back,-1,backgroundConvMat, cv::Point(-1,-1));
    cv::dilate(movieFrameMatDiff4Back, movieFrameMatDiff4Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal4;
    double maxValTrash4;
    cv::minMaxLoc(movieFrameMatDiff4Back, &backVal4, &maxValTrash4);
    cv::Scalar sumt4=cv::sum(movieFrameMatDiff4-backVal4);
    NSLog(@"sumt4 is %f", sumt4[0]);
    
    //new background calcs5
    cv::Scalar sum5=cv::sum(movieFrameMatDiff5);
    NSLog(@"sum5 is %f", sum5[0]);
    cv::Mat movieFrameMatDiff5Back=movieFrameMatDiff5+movieFrameMatBW;
    //cv::filter2D(movieFrameMatDiff5Back,movieFrameMatDiff5Back,-1,backgroundConvMat, cv::Point(-1,-1));
    cv::dilate(movieFrameMatDiff5Back, movieFrameMatDiff5Back, backgroundConvMat, cv::Point(-1,-1),1,cv::BORDER_CONSTANT, cv::Scalar(cv::morphologyDefaultBorderValue()));
    double backVal5;
    double maxValTrash5;
    cv::minMaxLoc(movieFrameMatDiff5Back, &backVal5, &maxValTrash5);
    cv::Scalar sumt5=cv::sum(movieFrameMatDiff5-backVal5);
    NSLog(@"sumt5 is %f", sumt5[0]);
    
    double backValCorr=2;
    
    if (focusMeasure2>200000) {
        backValCorr=2;
    }
    if (focusMeasure2>100000) {
        backValCorr=2;
    }
    
    if (focusMeasure2<50000) {
        backValCorr=1.75;
    }
    if (focusMeasure2<25000) {
        backValCorr=1.5;
    }
    
    if (focusMeasure2<10000) {
        backValCorr=1.25;
    }
    movieFrameMatDiff1=movieFrameMatDiff1-backVal1*backValCorr;
    movieFrameMatDiff2=movieFrameMatDiff2-backVal2*backValCorr;
    movieFrameMatDiff3=movieFrameMatDiff3-backVal3*backValCorr;
    movieFrameMatDiff4=movieFrameMatDiff4-backVal4*backValCorr;
    movieFrameMatDiff5=movieFrameMatDiff5-backVal5*backValCorr;
    
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
    
    //imagewriting
    /*UIImage * testui;
     cv::Mat test=movieFrameMatDiff1.clone();
     test.convertTo(test, CV_8UC1);
     testui = [[UIImage alloc] initWithCVMat:test];
     UIImageWriteToSavedPhotosAlbum(testui,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    //imagewriting
    /*UIImage * testui0;
     cv::Mat test0=movieFrameMatDiff1.clone();
     test0.convertTo(test0, CV_8UC1);
     testui0 = [[UIImage alloc] initWithCVMat:test0];
     UIImageWriteToSavedPhotosAlbum(testui0,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    
    //imagewriting
    /*test0=movieFrameMatDiff2.clone();
     test0.convertTo(test0, CV_8UC1);
     testui0 = [[UIImage alloc] initWithCVMat:test0];
     UIImageWriteToSavedPhotosAlbum(testui0,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    
    //imagewriting
    /*test0=movieFrameMatDiff3.clone();
     test0.convertTo(test0, CV_8UC1);
     testui0 = [[UIImage alloc] initWithCVMat:test0];
     UIImageWriteToSavedPhotosAlbum(testui0,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    
    //imagewriting
    /*test0=movieFrameMatDiff4.clone();
     test0.convertTo(test0, CV_8UC1);
     testui0 = [[UIImage alloc] initWithCVMat:test0];
     UIImageWriteToSavedPhotosAlbum(testui0,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    
    //imagewriting
    /*test0=movieFrameMatDiff5.clone();
     test0.convertTo(test0, CV_8UC1);
     testui0 = [[UIImage alloc] initWithCVMat:test0];
     UIImageWriteToSavedPhotosAlbum(testui0,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    /*movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_16UC1);
     movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_16UC1);
     movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_16UC1);
     movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_16UC1);
     movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_16UC1);*/
    
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
    
    //median filter i times
    for(int i=0; i<0;i++) {
        cv::medianBlur(movieFrameMatDiff1,movieFrameMatDiff1,3);
        cv::medianBlur(movieFrameMatDiff2,movieFrameMatDiff2,3);
        cv::medianBlur(movieFrameMatDiff3,movieFrameMatDiff3,3);
        cv::medianBlur(movieFrameMatDiff4,movieFrameMatDiff4,3);
        cv::medianBlur(movieFrameMatDiff5,movieFrameMatDiff5,3);
        
    }
    
    //imagewriting
    /*UIImage * testui0;
     cv::Mat test0=movieFrameMatDiff1.clone();
     test0.convertTo(test0, CV_8UC1);
     testui0 = [[UIImage alloc] initWithCVMat:test0];
     UIImageWriteToSavedPhotosAlbum(testui0,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here */
    
    /*//correct for flicker
     if (flicker1>0) movieFrameMatDiff1=movieFrameMatDiff1-(movieFrameMatDiff1db+6);
     else     //movieFrameMatDiff1=movieFrameMatDiff1-(movieFrameMatDiff1db);
     if (flicker2>0)
     movieFrameMatDiff2=movieFrameMatDiff2-(movieFrameMatDiff2db+6);
     else    //movieFrameMatDiff2=movieFrameMatDiff2-(movieFrameMatDiff2db);
     if (flicker3>0) movieFrameMatDiff3=movieFrameMatDiff3-(movieFrameMatDiff3db+6);
     else    // movieFrameMatDiff3=movieFrameMatDiff3-(movieFrameMatDiff3db);
     if (flicker4>0) movieFrameMatDiff4=movieFrameMatDiff4-(movieFrameMatDiff4db+6);
     else    // movieFrameMatDiff4=movieFrameMatDiff4-(movieFrameMatDiff4db);
     if (flicker5>0) movieFrameMatDiff5=movieFrameMatDiff5-(movieFrameMatDiff5db+6);
     else    // movieFrameMatDiff5=movieFrameMatDiff5-(movieFrameMatDiff5db);
     */
    
    movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_8UC1);
    movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_8UC1);
    movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_8UC1);
    movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_8UC1);
    movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_8UC1);
    
    int thresh=1;
    NSLog(@"backvals are %f, %f, %f, %f, %f", backVal1,backVal2,backVal3,backVal4,backVal5);
    //(cv::vector <cv::Point>) getLocalMaxima:(const cv::Mat) src:(int) matchingSize: (int) threshold: (int) gaussKernel:(int) starti :(int) endi
    [self getLocalMaxima:movieFrameMatDiff1: 17: thresh: 0:1:32];
    movieFrameMatDiff1.convertTo(movieFrameMatDiff1, CV_8UC1);
    cv::Mat movieFrameMatForWatGray;
    threshold(movieFrameMatDiff1, movieFrameMatForWatGray, 1, 255, CV_THRESH_TOZERO);
    threshold(movieFrameMatDiff1, movieFrameMatDiff1, 1, 255, CV_THRESH_BINARY);
    cv::Mat movieFrameMatDiff1ForWat=movieFrameMatDiff1.clone();
    
    [self getLocalMaxima:movieFrameMatDiff2: 17: thresh: 0:33:60];
    movieFrameMatDiff2.convertTo(movieFrameMatDiff2, CV_8UC1);
    threshold(movieFrameMatDiff2, movieFrameMatForWatGray, 1, 255, CV_THRESH_TOZERO);
    threshold(movieFrameMatDiff2, movieFrameMatDiff2, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff2.clone();
    
    [self getLocalMaxima:movieFrameMatDiff3: 17: thresh: 0:61:90];
    movieFrameMatDiff3.convertTo(movieFrameMatDiff3, CV_8UC1);
    threshold(movieFrameMatDiff3, movieFrameMatDiff3, 1, 255, CV_THRESH_BINARY);
    threshold(movieFrameMatDiff3, movieFrameMatDiff3, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff3.clone();
    
    [self getLocalMaxima:movieFrameMatDiff4: 17: thresh: 0:91:120];
    movieFrameMatDiff4.convertTo(movieFrameMatDiff4, CV_8UC1);
    threshold(movieFrameMatDiff4, movieFrameMatDiff4, 1, 255, CV_THRESH_BINARY);
    threshold(movieFrameMatDiff4, movieFrameMatDiff4, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff4.clone();
    
    [self getLocalMaxima:movieFrameMatDiff5: 17: thresh: 0:121:150];
    movieFrameMatDiff5.convertTo(movieFrameMatDiff5, CV_8UC1);
    threshold(movieFrameMatDiff5, movieFrameMatDiff5, 1, 255, CV_THRESH_BINARY);
    threshold(movieFrameMatDiff5, movieFrameMatDiff5, 1, 255, CV_THRESH_BINARY);
    movieFrameMatDiff1ForWat=movieFrameMatDiff5.clone();
    /*
     findContours( movieFrameMatDiff1, contours, hierarchy,
     CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE );
     [self countContours:contours:hierarchy:1:32];
     
     findContours( movieFrameMatDiff2, contours, hierarchy,
     CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE, cv::Point(0,0) );
     
     [self countContours:contours:hierarchy:33:60];
     
     findContours( movieFrameMatDiff3, contours, hierarchy,
     CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE );
     [self countContours:contours:hierarchy:61:90];
     
     findContours( movieFrameMatDiff4, contours, hierarchy,
     CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE );
     [self countContours:contours:hierarchy:91:120];
     
     findContours( movieFrameMatDiff5, contours, hierarchy,
     CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE );
     [self countContours:contours:hierarchy:121:150];
     */
    numWorms=numWorms/5;
    NSLog(@"numWorms %f", numWorms);
    
    movieFrameMatDiff.release();
    movieFrameMatDiff1.release();
    movieFrameMatDiff2.release();
    movieFrameMatDiff3.release();
    movieFrameMatDiff4.release();
    movieFrameMatDiff5.release();
    movieFrameMatBW.release();
    
    return coordsArray;
}

-(cv::vector <cv::Point>) getLocalMaxima:(const cv::Mat) src:(int) matchingSize: (int) threshold: (int) gaussKernel:(int) starti :(int) endi {
    cv::vector <cv::Point> vMaxLoc(0);
    //MatchingSize=14;
    vMaxLoc.reserve(100); // Reserve place for fast access
    cv::Mat processImg = src.clone();
    int w = src.cols;
    int h = src.rows;
    //cv::Mat out=cv::Mat::zeros(H,W,CV_8UC1);
    //matchingSize=20;
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
    //threshold=5;
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
                    //NSLog(@"%i %i", x+LocMax.x, y+LocMax.y);
                    int xi=x+locMax.x;
                    int yi= y+locMax.y;
                    //out.at<uchar>( y+LocMax.y,x+LocMax.x) = 255;
                    NSNumber *x=[NSNumber numberWithInt:xi];
                    //[coordsArray addObject:x];
                    //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
                    NSNumber *y=[NSNumber numberWithInt:yi];
                    //[coordsArray addObject:y];
                    NSNumber *start = [NSNumber numberWithInt:starti];
                    //[coordsArray addObject:start];
                    NSNumber *end = [NSNumber numberWithInt:endi];
                    //[coordsArray addObject:end];
                    [coordsArray addObject:x];
                    [coordsArray addObject:y];
                    [coordsArray addObject:start];
                    [coordsArray addObject:end];
                    numWorms=numWorms+1;
                }
            }
        }
        k += w;
    }
    return vMaxLoc;
}


-(cv::Mat) doWatershed:(cv::Mat) movieFrameMatDiff1ForWat: (cv::Mat) movieFrameMatDiff1ForWatGray {
    
    //test watershed
    cv::Mat kernel= cv::Mat::ones(3, 3, CV_32FC1);
    
    //sure_bg = cv2.dilate(movieFrameMatWat,kernel,iterations=3)
    cv::Mat sureBG;
    cv::Mat element = getStructuringElement(CV_SHAPE_RECT, cv::Size( 3,3 ));
    cv::morphologyEx(movieFrameMatDiff1ForWat,sureBG, CV_MOP_DILATE, element );
    cv::morphologyEx(sureBG,sureBG, CV_MOP_DILATE, element );
    cv::morphologyEx(sureBG,sureBG, CV_MOP_DILATE, element );
    //cv::filter2D(movieFrameMatWat,sureBG,-1,kernel, cv::Point(-1,-1));
    //cv::filter2D(sureBG,sureBG,-1,kernel, cv::Point(-1,-1));
    //cv::filter2D(sureBG,sureBG,-1,kernel, cv::Point(-1,-1));
    
    //dist_transform = cv2.distanceTransform(opening,cv2.DIST_L2,5)
    cv::Mat distTrans;
    distanceTransform(movieFrameMatDiff1ForWat, distTrans, CV_DIST_L2, 5);
    //ret, sure_fg = cv2.threshold(dist_transform,0.7*dist_transform.max(),255,0)
    cv::Mat sureFG;
    double maxVal;
    double minValTrash;
    cv::minMaxLoc(distTrans, &minValTrash, &maxVal);
    
    threshold(distTrans, sureFG,0.5*maxVal, 255, CV_THRESH_BINARY);
    cv::Mat unknown;
    sureFG.convertTo(sureFG, CV_8UC1);
    cv::subtract(sureBG, sureFG, unknown);
    int compCount = 0;
    cv::vector<cv::vector<cv::Point> > contours2;
    cv::vector<cv::Vec4i> hierarchy2;
    
    findContours(sureFG, contours2, hierarchy2, CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE);
    cv::Mat markers=cv::Mat::ones(sureFG.size(), CV_32S);
    
    if( !contours2.empty() ){
        
        //cv::Mat markers(sureFG.size(), CV_32S);
        markers = cv::Scalar::all(0);
        int idx = 0;
        for( ; idx >= 0; idx = hierarchy2[idx][0], compCount++ ) {
            drawContours(markers, contours2, idx, cv::Scalar::all(compCount+1), -1, 8, hierarchy2, INT_MAX);
        }
        
        markers=markers+1;
        unknown.convertTo(unknown, CV_32S);
        markers=markers-(unknown/255);
        cv::Mat movieFrameMatWatRGB;
        cvtColor(movieFrameMatDiff1ForWatGray, movieFrameMatWatRGB, CV_GRAY2RGB);
        //movieFrameMatWat.convertTo(movieFrameMatWatRGB, CV_8UC3);
        watershed( movieFrameMatWatRGB, markers );
        markers=markers+1;
        markers.convertTo(markers, CV_8UC1);
        threshold(markers, markers,1, 1, CV_THRESH_BINARY);
        
        //markers.convertTo(markers,CV_8UC1);'
        /*UIImage * diff3;
         cv::Mat movieFrameMatDiff38;
         markers.convertTo(movieFrameMatDiff38, CV_8UC1);
         diff3 = [[UIImage alloc] initWithCVMat:movieFrameMatDiff38*255];
         UIImageWriteToSavedPhotosAlbum(diff3,
         self, // send the message to 'self' when calling the callback
         @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
         NULL); // you generally won't need a contextInfo here */
        
    }
    markers.convertTo(markers, CV_8UC1);
    return markers;
    
    
}

- (void) countContours:(cv::vector<cv::vector<cv::Point> >) contours :(cv::vector<cv::Vec4i>) hierarchy:(int) starti :(int) endi {
    cv::RNG rng(12345);
    
    cv::Mat drawing = cv::Mat::zeros(360,480, CV_8UC3 );
    
    for(int idx = 0;idx<contours.size(); idx++)
        
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        drawContours( drawing, contours, idx, color, 2, 8, hierarchy, 0, cv::Point() );
        
        //calculate moments
        cv::Moments mom;
        mom=cv::moments(contours[idx], true);
        //get centroids
        cv::Point2f mc;
        mc = cv::Point2f( mom.m10/mom.m00 ,mom.m01/mom.m00 );
        
        
        double len=contourArea(contours[idx]);
        NSLog(@"found contour %f", len);
        
        if (len>14100) {
            numWorms=numWorms+8;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            //[coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            //[coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            //[coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            //[coordsArray addObject:end];
            
            for (int i=0; i<=7; i++){
                //just write again since we don't have real positions
                [coordsArray addObject:x];
                [coordsArray addObject:y];
                [coordsArray addObject:start];
                [coordsArray addObject:end];
                
            }
        }
        
        
        else if (len>12100) {
            numWorms=numWorms+7;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            //[coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            //[coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            //[coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            //[coordsArray addObject:end];
            
            for (int i=0; i<=6; i++){
                //just write again since we don't have real positions
                [coordsArray addObject:x];
                [coordsArray addObject:y];
                [coordsArray addObject:start];
                [coordsArray addObject:end];
                
            }
        }
        
        
        else if (len>10100) {
            numWorms=numWorms+6;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            //[coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            //[coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            //[coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            //[coordsArray addObject:end];
            
            for (int i=0; i<=5; i++){
                //just write again since we don't have real positions
                [coordsArray addObject:x];
                [coordsArray addObject:y];
                [coordsArray addObject:start];
                [coordsArray addObject:end];
                
            }
        }
        else if (len>8100) {
            numWorms=numWorms+5;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            //[coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            //[coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            //[coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            //[coordsArray addObject:end];
            for (int i=0; i<=4; i++){
                //just write again since we don't have real positions
                [coordsArray addObject:x];
                [coordsArray addObject:y];
                [coordsArray addObject:start];
                [coordsArray addObject:end];
                
            }
            
        }
        
        else if (len>6100) {
            numWorms=numWorms+4;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            //[coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            //[coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            //[coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            //[coordsArray addObject:end];
            for (int i=0; i<=3; i++){
                //just write again since we don't have real positions
                [coordsArray addObject:x];
                [coordsArray addObject:y];
                [coordsArray addObject:start];
                [coordsArray addObject:end];
                
            }
            
        }
        
        else if (len>4100) {
            numWorms=numWorms+3;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            //[coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            //[coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            //[coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            //[coordsArray addObject:end];
            for (int i=0; i<=2; i++){
                //just write again since we don't have real positions
                [coordsArray addObject:x];
                [coordsArray addObject:y];
                [coordsArray addObject:start];
                [coordsArray addObject:end];
                
            }
            
        }
        
        else if (len>2100) {
            numWorms=numWorms+2;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            //[coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            //[coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            //[coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            //[coordsArray addObject:end];
            
            for (int i=0; i<=1; i++){
                //just write again since we don't have real positions
                [coordsArray addObject:x];
                [coordsArray addObject:y];
                [coordsArray addObject:start];
                [coordsArray addObject:end];
                
            }
            
        }
        
        if (len>100) {
            numWorms=numWorms+1;
            //NSNumber *x = [NSNumber numberWithInt:contours[idx][0].x];
            NSNumber *x=[NSNumber numberWithInt:mc.x];
            [coordsArray addObject:x];
            //NSNumber *y = [NSNumber numberWithInt:contours[idx][0].y];
            NSNumber *y=[NSNumber numberWithInt:mc.y];
            [coordsArray addObject:y];
            NSNumber *start = [NSNumber numberWithInt:starti];
            [coordsArray addObject:start];
            NSNumber *end = [NSNumber numberWithInt:endi];
            [coordsArray addObject:end];
            
        }
        else {
            //NSLog(@"found small contour %f", len);
        }
    }
    /*UIImage * diff2;
     cv::Mat movieFrameMatDiff28;
     drawing.convertTo(movieFrameMatDiff28, CV_8UC1);
     diff2 = [[UIImage alloc] initWithCVMat:movieFrameMatDiff28];
     
     UIImageWriteToSavedPhotosAlbum(diff2,
     self, // send the message to 'self' when calling the callback
     @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
     NULL); // you generally won't need a contextInfo here*/
    
}

//cv::vector <cv::Point> GetLocalMaxima(const cv::Mat Src,int MatchingSize, int Threshold, int GaussKernel  )
//cv::Mat GetLocalMaxima(const cv::Mat Src,int MatchingSize, int Threshold, int GaussKernel  )


- (void)thisImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void*)ctxInfo {
    if (error) {
        NSLog(@"error saving image");
        
    } else {
        NSLog(@"image saved in photo album");
    }
}


@end
