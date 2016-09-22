//
//  SetupController.h
//  HA-UI
//
//  Changed by Marcel Kermer on 11/02/16.
//  Copyright (c) 2015 Z-Wave Europe GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GCDAsyncSocket.h"
#import "AFHTTPRequestOperationManager.h"
#import "AFHTTPRequestOperation.h"

@interface SetupController : UIViewController<UITextFieldDelegate, GCDAsyncSocketDelegate, UIScrollViewDelegate, UIAlertViewDelegate, UIWebViewDelegate>
{
    CGPoint contentOffset;
    BOOL isScrolled;
    NSNumber *copied;
    NSString *lastIP;
    NSString *oldLogin;
}

@property (strong, nonatomic) IBOutlet UITextField *ipField;
@property (strong, nonatomic) IBOutlet UITextField *loginField;
@property (strong, nonatomic) IBOutlet UITextField *passField;
@property (strong, nonatomic) IBOutlet UITextField *loginName;
@property (strong, nonatomic) IBOutlet UITextField *password;
@property (strong, nonatomic) IBOutlet UIImageView *ipCheck;
@property (strong, nonatomic) IBOutlet UIImageView *credCheck;
@property (strong, nonatomic) IBOutlet UIScrollView *myScroll;
@property (strong, nonatomic) IBOutlet UIButton *saveButton;
@property (strong, nonatomic) IBOutlet UIProgressView *progress;
@property (strong, nonatomic) IBOutlet UIButton *cancelButton;
@property (strong, nonatomic) IBOutlet UISwitch *force;

- (void)startScan;
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
- (IBAction)autodetect:(id)sender;
- (IBAction)save:(id)sender;
- (void)testCredentialsWith:(NSString *)login And:(NSString *)pass;
- (void)moveBar;

@end
