
#import "AppDelegate.h"
#import "LockTimer.h"

#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak) IBOutlet NSImageView *imageView;

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSButton *registerButton;

@end

NSString * const client_id = @"10573261";
NSString * const client_secret = @"ZTESzOtELk37WDCAyGXWY5LM7niXwbIW";
NSString * const API_KEY = @"kw5KRljuMq4W64HYetziaLnA";
NSString * const grant_type = @"client_credentials";

@implementation AppDelegate{
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
    NSLog(@"handleTimer %i", date);
}

- (void)setupCaptureSession
{
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
    
    //根据NSData生成Base64编码的String
    NSString *base64Encode = [imageData base64EncodedStringWithOptions:0];
    NSLog(@"Encode:%@", base64Encode);
    
    [self onStartRegister:base64Encode];
    
    
    //图片写文件
//    NSData *nsdata = [@"iOS Developer Tips encode in Base64" dataUsingEncoding:NSUTF8StringEncoding];

//    NSString *imageType = @"jpg";
//
//    NSDate *date = [NSDate new];
//    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//    formatter.dateFormat = @"yyyy-MM-dd HH:ss:mm";
//    NSString *dateStr = [formatter stringFromDate:date];
//
//    NSString *imagePath = [NSString stringWithFormat:@"%@/%@.%@",NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0],dateStr,imageType];
//
//    BOOL ret = [imageData writeToFile:imagePath atomically:YES];
    
//    if (ret)
    {
        _buffer = nil;
    }
}

#pragma mark -- 实现代理方法 
//每当AVCaptureVideoDataOutput实例输出一个新视频帧时就会调用此函数
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //NSLog(@"captureOutput %i" ,_takePhoto);
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

NSString* accessToken;
//app 启动
-(void) onAppStart{
    [self startTimer];
    
    [self checkAccessToken];
}

-(void) stopTimer{
    if (self._lockTimer!=nil){
        [self._lockTimer stopTimer];
    }
}

-(void) startTimer{
    void (^myBlock)(NSTimer*)=^(NSTimer* timer){
        [self handleTimer:timer];
    };
    
    self._lockTimer = [[LockTimer alloc] initWithGap:5 block:myBlock];
    [self._lockTimer startTimer];
}

-(BOOL) hasRegistered {
    NSString* value = [self getDataFromPlist:@"registered"];
    
    return [@"yes" isEqualToString:value];
}

//注册后回调
-(void) registeredSuccess:(BOOL) success {
    //TODO
    if (success) {
        [self writeDataToPlist :@"registered" value:@"yes"];
    }
}

//获取token
-(NSString*) getAccessToken {
    return [self getDataFromPlist:@"token"];
}

//获取token成功回调
-(void) getAccessTokenSuccess:(BOOL)success token:(NSString*)token {
    NSLog(@"getAccessToken Success:%i",success);
    if (success) {
        [self writeDataToPlist :@"token" value:token];
    }
    
    [self checkAccessToken];
}

-(void) checkAccessToken{
    accessToken = [self getAccessToken];
    if (accessToken==nil) {
        [self onStartGetAccessToken];
        return;
    } else {
        if ([self hasRegistered]) {
            [self startTimer];
        } else {
            //注册提示
            [self.registerButton setTitle:@"请注册"];
        }
    }
}

//人脸识别，UI线程调用
-(void) recognitionFace{
    //TODO  震熙
}

-(void)onStartGetAccessToken {
    NSLog(@"开始获取AccessToken");
    NSString* url = @"https://aip.baidubce.com/oauth/2.0/token";
    NSString* grant_type = @"client_credentials";
//    client_id,client_secret
    NSDictionary* dictionary = @{
                                 @"grant_type":grant_type,
                                 @"client_id":client_id,
                                 @"client_secret":client_secret
                                };
    //TODO  震熙
}

//注册人脸，UI线程调用
-(void) onStartRegister:(NSString*)base64data {
    NSLog(@"onStartRegister data:%s", base64data);
    NSString* url = @"";
    NSString* uid = @"";
    NSString* user_info = uid;
    NSString* groupId = uid;
    NSString* image = base64data;
    NSString* action_type = @"replace";
    NSString* access_token = [self getAccessToken];
    //TODO  震熙
    NSDictionary* dictionary = @{
                                 @"uid":uid,
                                 @"user_info":user_info,
                                 @"groupId":groupId,
                                 @"image":base64data,
                                 @"action_type":action_type,
                                  @"access_token":access_token
                                 };
}

- (NSString*)getDataFromPlist:(NSString*)key {
    //沙盒获取路径
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [pathArray objectAtIndex:0];
    //获取文件的完整路径
    NSString *filePatch = [path stringByAppendingPathComponent:@"PropertyListTest.plist"];//没有会自动创建
    NSLog(@"file patch%@",filePatch);
    NSMutableDictionary *sandBoxDataDic = [[NSMutableDictionary alloc]initWithContentsOfFile:filePatch];
    if (sandBoxDataDic==nil) {
        return nil;
//        sandBoxDataDic = [NSMutableDictionary new];
//        sandBoxDataDic[@"test"] = @"test";
//        [sandBoxDataDic writeToFile:filePatch atomically:YES];
    } else {
        NSLog(@"sandBox %@",sandBoxDataDic);//直接打印数据
        return sandBoxDataDic[key];
    }
}

- (void)writeDataToPlist:(NSString*)key value:(NSString*)value {
    //这里使用位于沙盒的plist（程序会自动新建的那一个）
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [pathArray objectAtIndex:0];
    //获取文件的完整路径
    NSString *filePatch = [path stringByAppendingPathComponent:@"PropertyListTest.plist"];
    NSMutableDictionary *sandBoxDataDic = [[NSMutableDictionary alloc]initWithContentsOfFile:filePatch];
    NSLog(@"old sandBox is %@",sandBoxDataDic);
    sandBoxDataDic[key] = value;
    [sandBoxDataDic writeToFile:filePatch atomically:YES];
    sandBoxDataDic = [[NSMutableDictionary alloc]initWithContentsOfFile:filePatch];
    NSLog(@"new sandBox is %@",sandBoxDataDic);
}

// 测试github pr
-(void) testPr {

}

@end
