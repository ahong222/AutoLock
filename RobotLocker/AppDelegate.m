
#import "AppDelegate.h"
#import "LockTimer.h"


#import <AVFoundation/AVFoundation.h>

@interface AppDelegate () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property(weak) IBOutlet NSImageView *imageView;

@property(weak) IBOutlet NSWindow *window;
@property(weak) IBOutlet NSButton *registerButton;
@end

NSString *const client_id = @"kw5KRljuMq4W64HYetziaLnA";
NSString *const client_secret = @"ZTESzOtELk37WDCAyGXWY5LM7niXwbIW";
NSString *const grant_type = @"client_credentials";
NSString* userId;
int sleeped;

@implementation AppDelegate {
    CMSampleBufferRef _buffer;
    //0: 1:takePhoto for register,2: takePhot for recongnizer
    int _takePhoto;
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
    NSLog(@"applicationWillTerminate");
    [self stopTimer];
}


- (void)applicationDidChangeScreenParameters:(NSNotification *)notification
{
    NSLog(@"applicationDidChangeScreenParameters %@, sleeped:%d",notification, sleeped);
    if (sleeped==2) {
        sleeped--;
    } else if (sleeped==1){
        sleeped=0;
        NSLog(@"解锁了");
        [self onAppStart];
    }
}


// 触发事件
- (void)handleTimer:(NSTimer *)theTimer {
    NSDateFormatter *dateFormator = [[NSDateFormatter alloc] init];
    dateFormator.dateFormat = @"yyyy-MM-dd  HH:mm:ss";
    NSString *date = [dateFormator stringFromDate:[NSDate date]];
    NSLog(@"handleTimer %i", date);
    
    _takePhoto = 2;
}

- (void)setupCaptureSession {
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
            [NSNumber numberWithInt:320], (id) kCVPixelBufferWidthKey,
            [NSNumber numberWithInt:240], (id) kCVPixelBufferHeightKey,
                    nil];

    AVCaptureVideoPreviewLayer *preLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    //preLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    preLayer.frame = CGRectMake(0, self.window.contentView.frame.size.height - 240, 320, 240);//self.window.contentView.frame.size.height - 240
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

    _takePhoto = 1;
}

- (void)getImage:(int)takePhotoType {
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
    
    //图片写文件
    NSString *imageType = @"jpg";
    
    NSDate *date = [NSDate new];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH:ss:mm";
    NSString *dateStr = [formatter stringFromDate:date];
    
    NSString *imagePath = [NSString stringWithFormat:@"%@/%@.%@",NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0],dateStr,imageType];
    
    BOOL ret = [imageData writeToFile:imagePath atomically:YES];
    NSLog(@"imagePath:%@", imagePath);
    
    //openssl base64 -in /Users/shen/Desktop/img.jpg -out /Users/shen/Desktop/img_2.jpg
    NSString* newPath = [NSString stringWithFormat:@"%@_base64", imagePath];
    NSString* command = [NSString stringWithFormat:@"openssl base64 -in %@ -out %@", imagePath, newPath];
    [self runSystemCommand:command];
    NSLog(@"command:%@", command);
    
    //根据NSData生成Base64编码的String
    NSString *base64Encode = [NSString stringWithContentsOfFile:newPath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"base64Encode:%@", base64Encode);

    if (takePhotoType == 1) {
        [self onStartRegister:base64Encode];
    } else if (takePhotoType == 2){
        [self onRecognizeFace:base64Encode];
    }

    
//    if (ret) {
    _buffer = nil;
}

#pragma mark -- 实现代理方法

//每当AVCaptureVideoDataOutput实例输出一个新视频帧时就会调用此函数
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //NSLog(@"captureOutput %i" ,_takePhoto);
    if (_takePhoto != 0) {
        int takePhotoType = _takePhoto;
        _takePhoto = 0;
        _buffer = sampleBuffer;
        [self getImage:takePhotoType];
    }
}

- (NSImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
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
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

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

- (void)watchKeyBoard {
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask | NSMouseMovedMask | NSMouseEnteredMask
                    | NSKeyDownMask | NSScrollWheel | NSCursorUpdate | NSOtherMouseDown | NSOtherMouseDragged

                                           handler:^(NSEvent *event) {
//                                               switch (event.type) {
//                                                   case NSOtherMouseDragged:
//                                                       NSLog(@"NSOtherMouseDragged");
//                                                       break;
//                                                   case NSOtherMouseDown:
//                                                       NSLog(@"NSOtherMouseDown");
//                                                       break;
//                                                   case NSCursorUpdate:
//                                                       NSLog(@"NSCursorUpdate");
//                                                       break;
//                                                   case NSScrollWheel:
//                                                       NSLog(@"NSScrollWheel");
//                                                       break;
//                                                   case NSKeyDownMask:
//                                                       NSLog(@"NSKeyDownMask");
//                                                       break;
//                                                   case NSLeftMouseDownMask:
//                                                       NSLog(@"NSLeftMouseDownMask");
//                                                       break;
//                                                   case NSMouseMovedMask:
//                                                       NSLog(@"NSMouseMovedMask");
//                                                       break;
//                                                   case NSMouseEnteredMask:
//                                                       NSLog(@"NSMouseEnteredMask");
//                                                       break;
//                                                   default:
//                                                       NSLog(@"其他");
//                                                       break;
//                                               }
                                               
                                               [self stopTimer];

                                           }
    ];

}

- (void)runSystemCommand:(NSString *)cmd {
    [[NSTask launchedTaskWithLaunchPath:@"/bin/sh"
                              arguments:@[@"-c", cmd]]
            waitUntilExit];
}

//锁屏
- (void)sleepMac {
    NSLog(@"锁屏");
    sleeped = 2;
    NSString *cmd = @"/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend";
    [self runSystemCommand:cmd];
}

NSString *accessToken;

//app 启动
- (void)onAppStart {
    [self initUUID];

    [self checkAccessToken];
}

- (void)stopTimer {
    NSLog(@"停止Timer");
    if (self._lockTimer != nil) {
        [self._lockTimer stopTimer];
    }
}

- (void)startTimer {
    NSLog(@"启动Timer");
    void (^myBlock)(NSTimer *)=^(NSTimer *timer) {
        [self handleTimer:timer];
    };

    self._lockTimer = [[LockTimer alloc] initWithGap:5 block:myBlock];
    [self._lockTimer startTimer];
}

- (BOOL)hasRegistered {
    NSString *value = [self getDataFromPlist:@"registered"];

    return [@"yes" isEqualToString:value];
}

//注册成功后回调
- (void)registeredSuccess:(BOOL)success {
    if (success) {
        [self writeDataToPlist:@"registered" value:@"yes"];
        
        [self startTimer];
    }
}

//获取token
- (NSString *)getAccessToken {
    if (accessToken != nil) {
        return accessToken;
    }
    return [self getDataFromPlist:@"token"];
}

//获取token成功回调
- (void)getAccessTokenSuccess:(BOOL)success token:(NSString *)token {
    NSLog(@"getAccessToken Success:%i, token:%@", success, token);
    if (success) {
        [self writeDataToPlist:@"token" value:token];
    }

    [self checkAccessToken];
}

- (void)checkAccessToken {
    accessToken = [self getAccessToken];
    if (accessToken == nil) {
        NSLog(@"==初次使用，没有AccessToken");
        [self onStartGetAccessToken];
        return;
    } else {
        if ([self hasRegistered]) {
            [self startTimer];
        } else {
            //注册提示
            NSLog(@"==初次使用，请注册");
            [self.registerButton setTitle:@"请注册"];
        }
    }
}

typedef enum REQUEST_TYPE : NSUInteger {
    SUCCESS,
    FAIL,
    NET_ERROR
} REQUEST_TYPE;

- (void)onRecognitionFaceComplete:(REQUEST_TYPE) type {
    switch (type) {
        case SUCCESS:
            NSLog(@"识别成功，不处理，继续监控，重新启动timer");
            [self startTimer];
            break;
        case FAIL:
            NSLog(@"识别失败，锁屏，停止监控timer");//(timer如果只运行一次，可以不需要停止)
            [self stopTimer];
            [self sleepMac];
            break;
        case NET_ERROR:
            NSLog(@"无网络，不处理，重新启动timer");
            [self startTimer];
            break;
        default:
            break;
    }
}

//人脸识别，UI线程调用
- (void)onRecognizeFace:(NSString *)base64data {
    NSLog(@"recognitionFace start.");
    NSString *url = @"https://aip.baidubce.com/rest/2.0/face/v2/verify";
    NSString *uid = [self getUUID];
    NSString *groupId = uid;
    NSString *image = base64data;
    NSString *access_token = [self getAccessToken];
    NSDictionary *dictionary = @{
            @"uid": uid,
            @"group_id": groupId,
            @"image": image,
            @"top_num": @"1",
            @"access_token": access_token
    };

    NSDictionary *headers = @{
            @"Content-Type": @"application/x-www-form-urlencoded"
    };

    void (^requestHandler)(NSURLResponse *, NSData *, NSError *)=^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError || data == nil) {
            NSLog(@"recognition face failed : network error");
            [self onRecognitionFaceComplete:NET_ERROR];
            return;
        } else {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
            NSArray *result = dict[@"result"];
            if (nil == result) {
                NSLog(@"recognition face failed : result == nil");
                [self onRecognitionFaceComplete:FAIL];
            } else {
                NSNumber * result_num = dict[@"result_num"];
                int resultSize = result_num.intValue;
                if(resultSize <= 0) {
                    NSLog(@"recognition face failed : result size <= 0");
                    [self onRecognitionFaceComplete:FAIL];
                } else {
                    NSNumber* resultAtFirst = result[0];
                    double finalScore = resultAtFirst.doubleValue;
                    if(finalScore > 80 && finalScore <= 100) {
                        NSLog(@"recognition face succeed : finalScore=[%a]", finalScore);
                        [self onRecognitionFaceComplete:SUCCESS];
                    } else {
                        [self onRecognitionFaceComplete:FAIL];
                        NSLog(@"recognition face failed : finalScore=[%a]", finalScore);
                    }
                }
            }
        }
    };
    [self postRequest:url params:dictionary headers:headers requestHandler:requestHandler];
}

- (void)onStartGetAccessToken {
    NSLog(@"开始获取AccessToken");
    NSString *grant_type = @"client_credentials";
    NSDictionary *params = @{
            @"grant_type": grant_type,
            @"client_id": client_id,
            @"client_secret": client_secret
    };

    // 路径
    NSString *path = [NSString stringWithFormat:@"https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=%@&client_secret=%@", client_id, client_secret];

    void (^requestHandler)(NSURLResponse *, NSData *, NSError *)=^(NSURLResponse *_Nullable response, NSData *_Nullable data, NSError *_Nullable connectionError) {
        NSLog(@"getAccessToken complete");
        if (connectionError || data == nil) {
            NSLog(@"getAccessToken failed : network error");
            [self getAccessTokenSuccess:NO token:nil];
            return;
        } else {
            NSLog(@"getAccessToken success data = [%@]", data);
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
            NSString *error = dict[@"error"];
            NSString *error_description = dict[@"error_description"];
            if (error) {
                NSLog(@"getAccessToken failed : error:%@\tdescription:%@\n", error, error_description);
                [self getAccessTokenSuccess:NO token:nil];
            } else {
                NSString *access_token = dict[@"access_token"];
                NSLog(@"getAccessToken succeed : access_token = %@\trefresh_token = %@\tsession_key = %@\tsession_key = %@\tsession_secret = %@", access_token, dict[@"refresh_token"], dict[@"session_key"], dict[@"session_secret"]);
                [self getAccessTokenSuccess:YES token:access_token];
            }
        }
    };

    NSLog(@"getAccessToken request start : path[%@]", path);
    NSString* jsonString = [[NSString alloc]initWithContentsOfURL:[NSURL URLWithString:path] encoding:NSUTF8StringEncoding error:nil];
    if(nil == jsonString) {
        [self getAccessTokenSuccess:NO token:nil];
        return;
    }
    NSLog(@"注册返回数据:%@", jsonString);
    //将字符串写到缓冲区。
    NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    //解析json数据，使用系统方法 JSONObjectWithData:  options: error:
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
    NSString *error = dict[@"error"];
    NSString *error_description = dict[@"error_description"];
    if (error) {
        NSLog(@"getAccessToken failed : error:%@\tdescription:%@\n", error, error_description);
        [self getAccessTokenSuccess:NO token:nil];
    } else {
        NSString *access_token = dict[@"access_token"];
//        NSLog(@"getAccessToken succeed : access_token = %@\trefresh_token = %@\tsession_key = %@\tsession_key = %@\tsession_secret = %@", access_token, dict[@"refresh_token"], dict[@"session_key"], dict[@"session_secret"]);
        [self getAccessTokenSuccess:YES token:access_token];
    }

//    [self postRequest:path params:nil headers:nil requestHandler:requestHandler];
}

//注册，UI线程调用
- (void)onStartRegister:(NSString *)base64data {

    NSLog(@"onStartRegister data:%@", base64data==nil?@"image is null":@"image ok");
    NSString *url = @"https://aip.baidubce.com/rest/2.0/face/v2/faceset/user/add";
    NSString *uid = [self getUUID];
    NSString *user_info = uid;
    NSString *groupId = uid;
    NSString *image = base64data;
    NSString *action_type = @"replace";
    NSString *access_token = [self getAccessToken];
    NSLog(@"onStartRegister : access_token=[%@]\timage not nil=[%@]", access_token, image!=nil);
    NSDictionary *dictionary = @{
            @"uid": uid,
            @"user_info": user_info,
            @"group_id": groupId,
            @"image": image,
            @"action_type": action_type,
            @"access_token": access_token
    };

    NSDictionary *headers = @{
            @"Content-Type": @"application/x-www-form-urlencoded"
    };

    void (^requestHandler)(NSURLResponse *, NSData *, NSError *)=^(NSURLResponse *_Nullable response, NSData *_Nullable data, NSError *_Nullable connectionError) {
        if (connectionError || data == nil) {
            NSLog(@"registered failed : network error");
            [self registeredSuccess:NO];
            return;
        } else {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
            NSString *log_id = dict[@"log_id"];
            NSString *error_code = dict[@"error_code"];
            NSString *error_msg = dict[@"error_msg"];
            if (error_code) {
                NSLog(@"registered failed : error_code:[%@]\terror_msg:[%@]\tlog_id:[%@]\n", error_code, error_msg, log_id);
                [self registeredSuccess:NO];
            } else {
                NSLog(@"registered succeed : log_id=[%@]", dict[@"log_id"]);
                [self registeredSuccess:YES];
            }
        }
    };

    [self postRequest:url params:dictionary headers:headers requestHandler:requestHandler];
}


- (NSString *)getDataFromPlist:(NSString *)key {
    //沙盒获取路径
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [pathArray objectAtIndex:0];
    //获取文件的完整路径
    NSString *filePatch = [path stringByAppendingPathComponent:@"PropertyListTest.plist"];//没有会自动创建
    NSLog(@"file path%@", filePatch);
    NSMutableDictionary *sandBoxDataDic = [[NSMutableDictionary alloc] initWithContentsOfFile:filePatch];
    if (sandBoxDataDic == nil) {
        sandBoxDataDic = [NSMutableDictionary new];
        [sandBoxDataDic writeToFile:filePatch atomically:YES];
        return nil;
    } else {
        NSLog(@"sandBox %@", sandBoxDataDic);//直接打印数据
        return sandBoxDataDic[key];
    }
}

- (void)writeDataToPlist:(NSString *)key value:(NSString *)value {
    //这里使用位于沙盒的plist（程序会自动新建的那一个）
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [pathArray objectAtIndex:0];
    //获取文件的完整路径
    NSString *filePatch = [path stringByAppendingPathComponent:@"PropertyListTest.plist"];
    NSMutableDictionary *sandBoxDataDic = [[NSMutableDictionary alloc] initWithContentsOfFile:filePatch];
    NSLog(@"old sandBox is %@", sandBoxDataDic);
    sandBoxDataDic[key] = value;
    [sandBoxDataDic writeToFile:filePatch atomically:YES];
    sandBoxDataDic = [[NSMutableDictionary alloc] initWithContentsOfFile:filePatch];
    NSLog(@"new sandBox is %@", sandBoxDataDic);
}

/**
 * 发起 HTTP POST 请求
 * @param path 请求的服务器地址
 * @param params 请求参数
 * @param headers 请求自定义头
 * @param requestHandler 请求回调
 */
- (void)postRequest:(NSString *)path params:(NSDictionary *)params headers:(NSDictionary *)headers requestHandler:(void (^)(NSURLResponse *, NSData *, NSError *))requestHandler {
    // 构建 NSURL
    NSURL *url = [NSURL URLWithString:path];

    // 构建 Request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    // 设置 Request
    request.timeoutInterval = 30;
    request.HTTPMethod = @"POST";

    if(nil != params) {
        //设置请求体
        NSLog(@"request path = [%@]", path);
        NSString *param = @"";
        int i = 0;
        for(NSString * key in params) {
            NSString* value = params[key];
            
            i++;
            NSString* formmat = i==0?@"%@=%@":@"&%@=%@";

            param = [param stringByAppendingFormat:formmat, key, params[key]];
        }
        // NSString --> NSData
        request.HTTPBody = [param dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        request.HTTPBody = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    }

    // 设置请求头
    if (headers != nil) {
        for (NSString *key in headers) {
            [request setValue:[headers valueForKey:key] forHTTPHeaderField:key];
        }
    }

    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:requestHandler];
}

- (NSString *)getUUID {
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/sbin/ioreg"];
    
    //ioreg -rd1 -c IOPlatformExpertDevice | grep -E '(UUID)'
    
    NSArray *arguments;
    arguments = [NSArray arrayWithObjects: @"-rd1", @"-c",@"IOPlatformExpertDevice",nil];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *string;
    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    //NSLog (@"grep returned:n%@", string);
    
    NSString *key = @"IOPlatformUUID";
    NSRange range = [string rangeOfString:key];
    
    NSInteger location = range.location + [key length] + 5;
    NSInteger length = 32 + 4;
    range.location = location;
    range.length = length;
    
    NSString *UUID = [string substringWithRange:range];
    
    
    UUID = [UUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSLog(@"UIID:%@",UUID);
    
    return UUID;
}

-(void)initUUID {
    NSString* uuid = [self getDataFromPlist:@"uuid"];
    if (uuid==nil) {
        uuid = [self getUUID];
        [self writeDataToPlist:@"uuid" value:uuid];
    }
    NSLog(@"initUUID:%@", uuid);
    userId = uuid;
}

@end
