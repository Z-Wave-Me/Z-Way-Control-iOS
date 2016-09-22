//
//  ViewController.h
//  HA-UI
//
//  Created by Marcel Z-Wave Europe GmbH on 10/12/14.
//  Copyright (c) 2014 Z-Wave Europe GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebviewController : UIViewController <UIScrollViewDelegate, UIWebViewDelegate, UIGestureRecognizerDelegate, UIAlertViewDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    NSString *login;
    NSString *password;
    NSString *loginName;
    NSString *passwordUI;
    BOOL loaded;
    BOOL useOutdoor;
    BOOL first;
    NSString *lastPath;
    BOOL firstAttempt;
    BOOL isDone;
    NSURLConnection *con;
}

@property (strong, nonatomic) NSString *ip;
@property (strong, nonatomic) IBOutlet UIWebView *webview;
@property (strong, nonatomic) IBOutlet UIImageView *touchView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *indicator;
@property (strong, nonatomic) IBOutlet UILabel *label;

-(void)testOutdoor;
-(void)handleLongPress:(UILongPressGestureRecognizer*)sender;
-(void)loadContent;

@end

