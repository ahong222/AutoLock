
#import "AppDelegate.h"
#import "LockTimer.h"

#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak) IBOutlet NSImageView *imageView;

@property (weak) IBOutlet NSWindow *window;
@end


@implementation AppDelegate

{
    CMSampleBufferRef _buffer;
    BOOL _takePhoto;
    NSImage *_image;
}

//程序启动入口
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [self setupCaptureSession];
    [self onAppStart];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


// 触发事件
- (void)handleTimer:(NSTimer *)theTimer
{
    NSDateFormatter *dateFormator = [[NSDateFormatter alloc] init];
    dateFormator.dateFormat = @"yyyy-MM-dd  HH:mm:ss";
    NSString *date = [dateFormator stringFromDate:[NSDate date]];
    NSLog(@"handleTimer %@", date);
}

- (void)setupCaptureSession
{
    void (^myBlock)(NSTimer*)=^(NSTimer* timer){
        [self handleTimer:timer];
    };
    
    LockTimer* _lockTimer = [[LockTimer alloc] initWithGap:5 block:myBlock];
    [_lockTimer startTimer];
    
    NSError *error = nil;
    
    // Create the session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = [AVCaptureDevice
                               defaultDeviceWithMediaType:AVMediaTypeVideo];//这里默认是使用后置摄像头，你可以改成前置摄像头
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                        error:&error];
    if (!input) {
        // Handling the error appropriately.
    }
    // - (BOOL)canAddInput:(AVCaptureInput *)input;
    
    if ([session canAddInput:input]) {
        
        [session addInput:input];
        NSLog(@"打开摄像头");
    } else {
        NSLog(@"不能打开摄像头");
    }
    
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    // Specify the pixel format
    output.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                            [NSNumber numberWithInt: 320], (id)kCVPixelBufferWidthKey,
                            [NSNumber numberWithInt: 240], (id)kCVPixelBufferHeightKey,
                            nil];
    
    AVCaptureVideoPreviewLayer* preLayer = [AVCaptureVideoPreviewLayer layerWithSession: session];
    //preLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    preLayer.frame = CGRectMake(0, 0, 320, 240);
    preLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.window.contentView.layer addSublayer:preLayer];
    // If you wish to cap the frame rate to a known value, such as 15 fps, set
    // minFrameDuration.
    //    output.minFrameDuration = CMTimeMake(1, 15);
    
    // Start the session running to start the flow of data
    [session startRunning];
    
    // Assign session to an ivar.
    //[self setSession:session];
}
- (IBAction)photo:(id)sender {
    
    _takePhoto = YES;
}

- (void)getImage
{
    NSImage *image = [self imageFromSampleBuffer:_buffer];
    _image = image;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = _image;
    });
    
    
    NSData *data = [image TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
    NSDictionary *imageProps = nil;
    NSNumber *quality = [NSNumber numberWithFloat:1];
    imageProps = [NSDictionary dictionaryWithObject:quality forKey:NSImageCompressionFactor];
    NSData *imageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
    
    NSString *imageType = @"jpg";
    
    NSDate *date = [NSDate new];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:ss:mm";
    NSString *dateStr = [formatter stringFromDate:date];
    
    NSString *imagePath = [NSString stringWithFormat:@"%@/%@.%@",NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0],dateStr,imageType];
    
    BOOL ret = [imageData writeToFile:imagePath atomically:YES];
    
    if (ret) {
        _buffer = nil;
    }
}

#pragma mark -- 实现代理方法 
//每当AVCaptureVideoDataOutput实例输出一个新视频帧时就会调用此函数
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (_takePhoto) {
        _takePhoto = NO;
        _buffer = sampleBuffer;
        [self getImage];
    }
}

- (NSImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    //UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    NSImage *image = [[NSImage alloc] initWithCGImage:quartzImage size:CGSizeMake(320, 240)];
    
    //    UIImage *image = [NSImage imageWithCGImage:quartzImage scale:1.0f orientation:UIImageOrientationRight];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

-(void)watchKeyBoard {
    
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask|NSMouseMovedMask|NSMouseEnteredMask
     |NSKeyDownMask|NSScrollWheel|NSCursorUpdate|NSOtherMouseDown|NSOtherMouseDragged
     
                                           handler:^(NSEvent *event) {
                                               switch (event.type) {
                                                   case NSOtherMouseDragged:
                                                       NSLog(@"NSOtherMouseDragged");
                                                       break;
                                                   case NSOtherMouseDown:
                                                       NSLog(@"NSOtherMouseDown");
                                                       break;
                                                   case NSCursorUpdate:
                                                       NSLog(@"NSCursorUpdate");
                                                       break;
                                                   case NSScrollWheel:
                                                       NSLog(@"NSScrollWheel");
                                                       break;
                                                   case NSKeyDownMask:
                                                       NSLog(@"NSKeyDownMask");
                                                       break;
                                                   case NSLeftMouseDownMask:
                                                       NSLog(@"NSLeftMouseDownMask");
                                                       break;
                                                   case NSMouseMovedMask:
                                                       NSLog(@"NSMouseMovedMask");
                                                       break;
                                                   case NSMouseEnteredMask:
                                                       NSLog(@"NSMouseEnteredMask");
                                                       break;
                                                   default:
                                                       NSLog(@"其他");
                                                       break;
                                               }
                                               
                                           }
     ];
    
}

-(void) runSystemCommand:(NSString*) cmd
{
    [[NSTask launchedTaskWithLaunchPath:@"/bin/sh"
                              arguments:@[@"-c", cmd]]
     waitUntilExit];
}

//锁屏
-(void) sleepMac{
    NSString* cmd = @"/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend";
    [self runSystemCommand:cmd];
}

//app 启动
-(void) onAppStart{
    
}

-(void) stopTimer{
    
}

-(void) startTimer{
    
}

-(BOOL) hasRegistered {
    return NO;
}

//注册后回调
-(void) registeredSuccess:(BOOL) success {
    //TODO
}

//人脸识别，UI线程调用
-(void) recognitionFace{
    
}

//注册，UI线程调用
-(void) onStartRegister{
    
}

// 测试github pr
-(void) testPr {

}

@end
