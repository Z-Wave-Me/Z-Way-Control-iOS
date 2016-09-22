//
//  ViewController.m
//  HA-UI
//
//  Created by Marcel Z-Wave Europe GmbH on 10/12/14.
//  Copyright (c) 2014 Z-Wave Europe GmbH. All rights reserved.
//

@import SystemConfiguration.CaptiveNetwork;
#import "WebviewController.h"
#import "Reachability.h"

@interface WebviewController ()

@end

@implementation WebviewController

@synthesize touchView, indicator, label;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //setup webview
    _webview.delegate = self;
    _webview.multipleTouchEnabled = NO;
    _webview.scalesPageToFit = NO;
    _webview.scrollView.bounces = NO;
    _webview.scrollView.delegate = self;
    [_webview.scrollView setShowsHorizontalScrollIndicator:NO];
    
    _webview.hidden = NO;
    firstAttempt = YES;
    
    //setup touchview for setup
    UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [recognizer setMinimumPressDuration:0.05];
    [touchView addGestureRecognizer:recognizer];
    touchView.hidden = NO;
    indicator.hidden = NO;
    label.hidden = NO;
    _webview.hidden = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    //load content when view appears
    if(!useOutdoor)
        useOutdoor = NO;
    [self testOutdoor];
    [self loadContent];
}

- (void)loadContent
{
    //load setup data from Defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.ip = [defaults objectForKey:@"IP"];
    login = [defaults objectForKey:@"Login"];
    password = [defaults objectForKey:@"PasswordUI"];
    lastPath = [defaults objectForKey:@"path"];
    loginName = [defaults objectForKey:@"LoginUI"];
    passwordUI = [defaults objectForKey:@"PasswordUI"];
    NSNumber *profileChanged = [defaults objectForKey:@"changed"];
    
    NSString *remote_login = [NSString stringWithFormat:@"%@/%@", login, loginName];
    
    
    NSURL *url;
    //go over find.z-wave.me if we are outdoor
    if(useOutdoor == YES)
    {
        _webview.hidden = YES;
        label.hidden = NO;
        indicator.hidden = NO;
        loaded = NO;
    
        NSLog(@"Outdoor");
        
        //send POST to login on find.z-wave.me
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://find.z-wave.me/zboxweb"]];
        NSMutableURLRequest *loginRequest;
        loginRequest = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
        
        NSString *postString = [NSString stringWithFormat:@"act=login&login=%@&pass=%@", remote_login, passwordUI];
        NSData *myRequestData = [postString dataUsingEncoding: NSUTF8StringEncoding];
        
        [loginRequest setHTTPMethod:@"POST"];
        [loginRequest setValue:@"*/*" forHTTPHeaderField:@"Accept"];
        [loginRequest setValue:@"gzip, deflate, sdch" forHTTPHeaderField:@"Accept-Encoding"];
        [loginRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[myRequestData length]] forHTTPHeaderField:@"Content-length"];
        [loginRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
        [loginRequest setHTTPBody:myRequestData];
        [_webview loadRequest:loginRequest];
    }
    //or instantly load local resources
    else
    {
        NSLog(@"Indoor");

        //get local resources
        NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *folderPath1 = [libraryDirectory stringByAppendingPathComponent:@"smarthome1"];
        NSString *folderPath2 = [libraryDirectory stringByAppendingPathComponent:@"smarthome2"];
        NSString *filePath = [folderPath1 stringByAppendingPathComponent:@"app/config.js"];
        
        
        NSString *oldIP = [[NSUserDefaults standardUserDefaults] objectForKey:@"oldIP"];
        
        if(oldIP == nil)
        {
        oldIP = @"none";
        }
        
        NSString *script = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        
        //for remote access on demo home
        if([self.ip containsString:@"zwave.dyndns.org"])
        {
            if([script containsString:@"'/'"])
                script = [script stringByReplacingOccurrencesOfString:@"'/'" withString:[NSString stringWithFormat:@"'http://%@/'", self.ip]];
        }
        //else normal procedure
        else
        {
            //set IP in config file
            if([script containsString:@"'/'"])
                script = [script stringByReplacingOccurrencesOfString:@"'/'" withString:[NSString stringWithFormat:@"'http://%@:8083/'", self.ip]];
            else if([script containsString:oldIP])
                script = [script stringByReplacingOccurrencesOfString:oldIP withString:[NSString stringWithFormat:@"%@", self.ip]];
            else if([script containsString:@"https://find.z-wave.me/"])
                script = [script stringByReplacingOccurrencesOfString:@"https://find.z-wave.me/" withString:[NSString stringWithFormat:@"http://%@:8083/", self.ip]];
        }
        
        [script writeToFile:[folderPath1 stringByAppendingPathComponent:@"app/config.js"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [script writeToFile:[folderPath2 stringByAppendingPathComponent:@"app/config.js"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        //reload if profile of smarthome changed
        if([profileChanged boolValue] == YES)
        {
            NSString *loginPath;
            if([lastPath isEqualToString:@"2"])
                loginPath = [libraryDirectory stringByAppendingPathComponent:@"smarthome1/index.html#/logout"];
            else
                loginPath = [libraryDirectory stringByAppendingPathComponent:@"smarthome2/index.html#/logout"];
        
            [defaults setObject:self.ip forKey:@"oldIP"];
        
            [_webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:loginPath]]];
        }
        //load normally if nothing changed
        else
        {
            NSString *loginPath;
            if([lastPath isEqualToString:@"2"])
                loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome1/index.html#/?login=%@&password=%@", loginName, passwordUI]];
            else
                loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome2/index.html#/?login=%@&password=%@", loginName, passwordUI]];
        
            [defaults setObject:self.ip forKey:@"oldIP"];
            [_webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:loginPath]]];
        }
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *currentURL = request.URL.absoluteString;
    NSLog(@"URL: %@", currentURL);
    
    if(![request.URL.absoluteString containsString:@"dashboard"])
    {
    
        //don't load requests that are not find.z-wave.me or local resources
        if(![request.URL.absoluteString containsString:@"smarthome"] && ![request.URL.absoluteString containsString:@"find.z"])
            return NO;

        //catch logout loop and redirect to login
        if([request.URL.absoluteString containsString:@"logout"])
        {
            //at second logout, redirect to login
            if(firstAttempt == NO)
            {
                NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            
                NSNumber *profileChanged = [NSNumber numberWithBool:NO];
                [[NSUserDefaults standardUserDefaults] setObject:profileChanged forKey:@"changed"];
            
                NSString *loginPath;
                if([lastPath isEqualToString:@"2"])
                    loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome1/index.html#/?login=%@&password=%@", loginName, passwordUI]];
                else
                    loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome2/index.html#/?login=%@&password=%@", loginName, passwordUI]];
            
                [_webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:loginPath]]];
            }
            //one logout is okay
            else
                firstAttempt = NO;
        }

        //start as connection to authenticate
        if(!isDone)
        {
            NSLog(@"go into to set con");
            isDone = NO;
            con = [[NSURLConnection alloc] initWithRequest:request delegate:self];
            [con start];
            return NO;
        }
    }
    return YES;
}

//authenticate
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if([challenge previousFailureCount] == 0)
    {
        isDone = YES;
        
        NSURLCredential *cred = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        [[challenge sender] useCredential:cred forAuthenticationChallenge:challenge];
    }
    else
        [[challenge sender] cancelAuthenticationChallenge:challenge];
}

//cancel request after auth and load in webview
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    isDone = YES;
    [_webview loadRequest:con.originalRequest];
    [con cancel];
}

//authenticate with ssl
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    // use auto login on local resources
    if(![webView.request.URL.absoluteString containsString:@"login"] && ![webView.request.URL.absoluteString containsString:@"logout"] && ![webView.request.URL.absoluteString containsString:@"dashboard"])
    {
        NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        
        NSString *loginPath;
        if([lastPath isEqualToString:@"2"])
            loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome1/index.html#/?login=%@&password=%@", loginName, passwordUI]];
        else
            loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome2/index.html#/?login=%@&password=%@", loginName, passwordUI]];
        
        [_webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:loginPath]]];
    }
    
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *folderPath1 = [libraryDirectory stringByAppendingPathComponent:@"smarthome1"];
    NSString *folderPath2 = [libraryDirectory stringByAppendingPathComponent:@"smarthome2"];
    NSString *folderPath = [NSString new];
    
    if([lastPath isEqualToString:@"2"])
        folderPath = folderPath1;
    else
        folderPath = folderPath2;
    
    //set find.z-wave.me in config file when we use outdoor
    if(useOutdoor == YES && loaded == NO)
    {
        
        NSError *error;
        NSString *oldIP = [[NSUserDefaults standardUserDefaults] objectForKey:@"oldIP"];
        if(!oldIP)
            oldIP = self.ip;
        
        
        NSString *filePath = [folderPath stringByAppendingPathComponent:@"app/config.js"];
        
        NSString *script = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
        
        if([script containsString:oldIP])
            script = [script stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"http://%@:8083/", oldIP] withString:@"https://find.z-wave.me/"];
        else if([script containsString:self.ip])
            script = [script stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"http://%@:8083/", self.ip] withString:@"https://find.z-wave.me/"];
        else if([script containsString:@"'/'"])
            script = [script stringByReplacingOccurrencesOfString:@"'/'" withString:@"'https://find.z-wave.me/'"];
        else if([script containsString:@"http://zwave.dyndns.org:8183/"])
            script = [script stringByReplacingOccurrencesOfString:@"http://zwave.dyndns.org:8183/" withString:@"https://find.z-wave.me/"];
        
        [script writeToFile:[folderPath1 stringByAppendingPathComponent:@"app/config.js"] atomically:YES encoding:NSUTF8StringEncoding error:&error];
        [script writeToFile:[folderPath2 stringByAppendingPathComponent:@"app/config.js"] atomically:YES encoding:NSUTF8StringEncoding error:&error];
        
        //use auto login on remote access
        NSString *loginPath;
        if([lastPath isEqualToString:@"2"])
            loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome1/index.html#/?login=%@&password=%@", loginName, passwordUI]];
        else
            loginPath = [libraryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"smarthome2/index.html#/?login=%@&password=%@", loginName, passwordUI]];
        
        [_webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:loginPath]]];
        loaded = YES;
    }
    else
    {
        
        //suppress selection of HTML elements
        indicator.hidden = YES;
        label.hidden = YES;
        [webView stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
        [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitUserSelect='none';"];
        
        _webview.hidden = NO;
    }
}

//save data when setup is called via touch view
- (void)handleLongPress:(UILongPressGestureRecognizer*)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:self.ip forKey:@"IP"];
        [defaults setObject:login forKey:@"Login"];
        [defaults setObject:password forKey:@"Password"];
        [defaults setObject:loginName forKey:@"LoginUI"];
        [defaults setObject:passwordUI forKey:@"PasswordUI"];
        
        [self performSegueWithIdentifier:@"WebSetup" sender:self];
    }
}

//set scroll offset
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.x > 0)
        scrollView.contentOffset = CGPointMake(0, scrollView.contentOffset.y);
}

//check network SSID to see if we changed the location and have to use outdoor anyway
- (NSDictionary *)getSSID
{
    NSArray *interfaceNames = CFBridgingRelease(CNCopySupportedInterfaces());
    NSDictionary *SSIDInfo;
    for (NSString *interfaceName in interfaceNames) {
        SSIDInfo = CFBridgingRelease(
                                     CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));
        
        BOOL isNotEmpty = (SSIDInfo.count > 0);
        if (isNotEmpty) {
            break;
        }
    }
    
    return SSIDInfo;
}


//test if we have to use outdoor
- (void)testOutdoor
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    
    reachability = [Reachability reachabilityForLocalWiFi];
    networkStatus = [reachability currentReachabilityStatus];
    
    //check if SSID changed without the setup changing
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *SSIDInfo = [self getSSID];
    NSString *SSID = [SSIDInfo objectForKey:@"SSID"];
    NSString *oldSSID;
    NSString *outdoor = [defaults objectForKey:@"outdoor"];
    
    //set SSID
    if([defaults objectForKey:@"SSID"])
        oldSSID = [defaults objectForKey:@"SSID"];
    else
        oldSSID = @"None";
    
    if(networkStatus == NotReachable)
        [touchView setImage:[UIImage imageNamed:@"weltkugelred.png"]];
    else
        [touchView setImage:[UIImage imageNamed:@"weltkugelgreen.png"]];

    //if we have wifi use indoor
    if ((networkStatus == ReachableViaWiFi || networkStatus == NotReachable) && ![outdoor isEqualToString:@"YES"])
    {
        //if SSID changed or we had outdoor before we have to reload
        if(useOutdoor == YES || ![SSID isEqualToString:oldSSID] || self.ip.length == 0)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            if([lastPath isEqualToString:@"1"])
            {
                lastPath = @"2";
                [defaults setObject:lastPath forKey:@"path"];
            }
            else
            {
                lastPath = @"1";
                [defaults setObject:lastPath forKey:@"path"];
            }
            
            //if SSID changed use outdoor
            if((![SSID isEqualToString:oldSSID] && ![oldSSID isEqualToString:@"None"]) || self.ip.length == 0 || [[defaults objectForKey:@"force"] isEqualToString:@"on"])
            {
                if(useOutdoor != YES)
                {
                    useOutdoor = YES;
                    if(networkStatus != NotReachable || self.ip.length == 0)
                        [self loadContent];
                }
            }
            else if(useOutdoor == NO && networkStatus != NotReachable)
                [self loadContent];
        }
    }
    //if not use outdoor URL
    else
    {
        //only reload if we are not already outdoor
        if(useOutdoor == NO)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            if([lastPath isEqualToString:@"1"])
            {
                lastPath = @"2";
                [defaults setObject:lastPath forKey:@"path"];
            }
            else
            {
                lastPath = @"1";
                [defaults setObject:lastPath forKey:@"path"];
            }
            
            useOutdoor = YES;
            [self loadContent];
        }
    }
    
    //check again after 15 seconds
    [self performSelector:@selector(testOutdoor) withObject:nil afterDelay:15.0];
}

@end
