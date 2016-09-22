//
//  SetupController.m
//  HA-UI
//
//  Changed by Marcel Kermer on 11/02/16.
//  Copyright (c) 2015 Z-Wave Europe GmbH. All rights reserved.
//

@import SystemConfiguration.CaptiveNetwork;
#import "SetupController.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include "WebviewController.h"

#define PORT 8083

@interface SetupController ()

@end

//setup socket connection
@implementation SetupController
{
    GCDAsyncSocket *asyncSocket;
    int count;
    NSString *ipRange;
    dispatch_queue_t queue;
}

@synthesize ipField, loginField, passField, ipCheck, credCheck, force;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //load old setup
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    ipField.text = [defaults objectForKey:@"oldIP"];
    [defaults setObject:@"" forKey:@"outdoor"];
    loginField.text = [defaults objectForKey:@"Login"];
    passField.text = [defaults objectForKey:@"Password"];
    NSString *state = [defaults objectForKey:@"force"];
    if(state != nil)
    {
        if([state isEqualToString:@"on"])
            [force setOn:YES];
        else
            [force setOn:NO];
    }
    else
        [force setOn:NO];
    
    NSString *password = [defaults objectForKey:@"PasswordUI"];
    NSString *loginName = [defaults objectForKey:@"LoginUI"];
    oldLogin = loginName;
    
    //save last IP
    if(ipField.text.length != 0)
        lastIP = ipField.text;
        
    
    if(password && loginName)
    {
        self.password.text = password;
        self.loginName.text = loginName;
    }
    
    //find own subnet in network
    count = 1;
    ipRange = [NSString new];
    contentOffset = self.myScroll.contentOffset;
    if(!copied)
        copied = [NSNumber numberWithBool:NO];
    
    copied = [defaults objectForKey:@"copied"];
    
    if(!queue)
        queue = dispatch_queue_create("Writer", NULL);
    
    ipRange = [self getIPAddress];
    
    //cut off last byte so we can search the subnet
    if([ipRange containsString:@"."] && ipField.text.length == 0)
    {
        while(![ipRange hasSuffix:@"."])
            ipRange = [ipRange substringToIndex:ipRange.length -1];
        
        //start scan in whole subnet
        [self startScan];
    }
    
    //get paths for reading and writing local files
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *sourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"smarthome"];
    NSString *folderPath1 = [libraryDirectory stringByAppendingPathComponent:@"smarthome1"];
    NSString *folderPath2 = [libraryDirectory stringByAppendingPathComponent:@"smarthome2"];
    NSString *cameraPath = [sourcePath stringByAppendingPathComponent:@"app/views/elements/widgets/cameraModal.html"];
    NSString *version = [defaults objectForKey:@"Version"];
    if(!version)
        version = @"";
    
    NSString *currentNumber = [[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSString *oldNumber = [version stringByReplacingOccurrencesOfString:@"." withString:@""];
    
    NSInteger current = [currentNumber integerValue];
    NSInteger old = [oldNumber integerValue];
    
    //check if first setup
    if([copied boolValue] == NO || [version isEqualToString:@""] || current > old)
    {
        self.saveButton.hidden = YES;
        self.cancelButton.hidden = YES;
        self.progress.hidden = NO;
        self.progress.progress = 0;
        copied = [NSNumber numberWithBool:NO];
        [defaults setObject:[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] forKey:@"Version"];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"First Setup" message:@"Please wait while the UI is being prepared." preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"First Setup" message:@"The first setup might take a while after you save your access." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        //[alert show];
        
        NSError *error;
        NSString *script = [NSString stringWithContentsOfFile:cameraPath encoding:NSUTF8StringEncoding error:&error];
        script = [script stringByReplacingOccurrencesOfString:@"{{widgetCamera.find.metrics.url}}" withString:@"{{cfg.server_url}}{{widgetCamera.find.metrics.url}}"];

        //write and copy async so the user doesn't get a stuck screen
        dispatch_async( queue ,
                       ^ {
                           NSString *oldIP = [[NSUserDefaults standardUserDefaults] objectForKey:@"oldIP"];
                           if(!oldIP)
                               oldIP = ipField.text;
                           
                           [self performSelectorOnMainThread:@selector(moveBar) withObject:nil waitUntilDone:NO];

                           [[NSFileManager defaultManager] removeItemAtPath:folderPath1 error:nil];
                           [[NSFileManager defaultManager] removeItemAtPath:folderPath2 error:nil];
                           
                           [[NSFileManager defaultManager] copyItemAtPath:sourcePath
                                                                       toPath:folderPath1
                                                                        error:nil];
                           [[NSFileManager defaultManager] copyItemAtPath:sourcePath
                                                                       toPath:folderPath2
                                                                        error:nil];
                           
                           [script writeToFile:[folderPath1 stringByAppendingPathComponent:@"app/views/elements/widgets/cameraModal.html"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
                           [script writeToFile:[folderPath2 stringByAppendingPathComponent:@"app/views/elements/widgets/cameraModal.html"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
                           
                           //show progress in progress bar
                           dispatch_async(dispatch_get_main_queue(), ^{
                               copied = [NSNumber numberWithBool:YES];
                               [self addSkipBackupAttributeToItemAtPath:folderPath1];
                               [self addSkipBackupAttributeToItemAtPath:folderPath2];
                               [[NSUserDefaults standardUserDefaults] setObject:copied forKey:@"copied"];
                               self.progress.hidden = YES;
                               self.saveButton.hidden = NO;
                               self.cancelButton.hidden = NO;
                           });
                       });
    }
}

- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *) filePathString
{
    NSURL *URL= [NSURL fileURLWithPath: filePathString];
    
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];

    return success;
}

//move the bar to show progress
- (void)moveBar
{
    //get data size from file paths
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *sourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"smarthome"];
    NSString *folderPath1 = [libraryDirectory stringByAppendingPathComponent:@"smarthome1"];
    NSString *folderPath2 = [libraryDirectory stringByAppendingPathComponent:@"smarthome2"];
    
    NSDictionary *source = [[NSFileManager defaultManager] attributesOfItemAtPath:sourcePath error:nil];
    NSDictionary *path1 = [[NSFileManager defaultManager] attributesOfItemAtPath:folderPath1 error:nil];
    NSDictionary *path2 = [[NSFileManager defaultManager] attributesOfItemAtPath:folderPath2 error:nil];
    
    //compare copied size with source size
    float actual = [self.progress progress];
    unsigned long long fileSize = (2*[source fileSize]);
    unsigned long long copiedSize = ([path1 fileSize] + [path2 fileSize]);
    
    //move bar until finished
    if (actual < 1)
    {
        self.progress.progress = ((float)copiedSize/(float)fileSize);
        [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(moveBar) userInfo:nil repeats:NO];
    }
}

//get own IP in network and start scanning with it
- (IBAction)autodetect:(id)sender
{
    ipRange = [self getIPAddress];
    
    if([ipRange containsString:@"."])
    {
        while(![ipRange hasSuffix:@"."])
            ipRange = [ipRange substringToIndex:ipRange.length -1];
        
        [self startScan];
    }
}

//scroll back if the view scrolled up
-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    [textField resignFirstResponder];
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && textField.tag != 1) || (UIInterfaceOrientationIsLandscape(interfaceOrientation) && textField.tag != 1))
    {
        [self.myScroll setContentOffset:contentOffset animated:YES];
        isScrolled = NO;
    }
    
    [self.view endEditing:YES];
    return  YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    //get view position if it's not already scrolled
    if(!isScrolled)
        contentOffset = self.myScroll.contentOffset;
    
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    //scroll the view if the keyboard would overlap it
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && textField.tag != 1) || (UIInterfaceOrientationIsLandscape(interfaceOrientation) && textField.tag != 1))
    {
        if(!isScrolled)
        {
            CGPoint newOffset;
            newOffset.x = contentOffset.x;
            newOffset.y = contentOffset.y;
            newOffset.y += 180;

            [self.myScroll setContentOffset:newOffset animated:YES];
            isScrolled = YES;
        }
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if(textField.tag == 1 && (textField.text.length != 0))
    {
        //save and check IP address
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:8083", textField.text]];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:0.5];
        NSError *error;
        NSURLResponse *response;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        //check the response
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        NSInteger responseStatusCode = [httpResponse statusCode];
        data = nil;
        
        if(responseStatusCode == 200)
        {
            NSURL *json_response = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:8083/ZAutomation/api/v1/system/remote-id", textField.text]];
            NSString *json_string = @"";
            json_string = [NSString stringWithFormat:@"%@", json_response ];
           
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString: json_string]];
            
            __block NSDictionary *json;
            [NSURLConnection sendAsynchronousRequest:request
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                       json = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:0
                                                                                error:nil];
                                       NSString *remote_id = @"";
                                       remote_id = [NSString stringWithFormat:@"%@", json[@"data"][@"remote_id"]];
                                       
                                       if(remote_id != nil)
                                       {
                                           loginField.text = remote_id;
                                       }
                                   }];
            
            [ipCheck setImage:[UIImage imageNamed:@"connected.png"]];
            
            //save SSID for later
            NSDictionary *SSIDInfo = [self getSSID];
            [[NSUserDefaults standardUserDefaults] setObject:[SSIDInfo objectForKey:@"SSID"] forKey:@"SSID"];
        }
        else
        {
            [ipCheck setImage:[UIImage imageNamed:@"wrong.png"]];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *outdoor = @"YES";
            [defaults setObject:outdoor forKey:@"outdoor"];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"IP not found and not saved" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    }
    //set variable if the user profile changed
    else if(textField.tag == 3 && textField.text.length != 0)
    {
        if(![textField.text isEqualToString:oldLogin])
        {
            NSNumber *profileChanged = [NSNumber numberWithBool:YES];
            [[NSUserDefaults standardUserDefaults] setObject:profileChanged forKey:@"changed"];
        }
    }
}

//test remote credentials
- (void)testCredentialsWith:(NSString *)login And:(NSString *)pass
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    manager.requestSerializer.timeoutInterval = 5.0;
    manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    [manager POST:@"https://find.zwave.me/zboxweb"
       parameters:@{@"act": @"login", @"login": login, @"pass" : pass}
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              
              if ([operation.response.allHeaderFields objectForKey:@"Set-Cookie"]) {
                  //wrong credentials
                 // [credCheck setImage:[UIImage imageNamed:@"wrong.png"]];
              }
              else {
                  //correct credentials
                 // [credCheck setImage:[UIImage imageNamed:@"connected.png"]];
              }
              
              
          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              //No connection
              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No connection possible" message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
              [alert show];
          }];
}

//go to the webview
- (IBAction)save:(id)sender
{
    if([self shouldPerformSegueWithIdentifier:@"showWeb" sender:self])
        [self performSegueWithIdentifier:@"showWeb" sender:self];
}

//extract SSID
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

//don't leave the view neither remote nor IP is set
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if(ipField.text.length == 0)
    {
       // if((loginField.text.length == 0) || (passField.text.length == 0))
         if((loginField.text.length == 0)) // CHANGE: MK this field is no longer needed
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Please enter either IP or remote access data" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return NO;
        }
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    [self.view endEditing:YES];
    
    //save the data when it's not cancelled
    if(![segue.identifier isEqualToString:@"cancelSetup"])
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:ipField.text forKey:@"IP"];
        [defaults setObject:loginField.text forKey:@"Login"];
        [defaults setObject:passField.text forKey:@"Password"];
        [defaults setObject:self.loginName.text forKey:@"LoginUI"];
        [defaults setObject:self.password.text forKey:@"PasswordUI"];
        
        if([force isOn])
            [defaults setObject:@"on" forKey:@"force"];
        else
            [defaults setObject:@"off" forKey:@"force"];
        
        WebviewController *controller = segue.destinationViewController;
        controller.ip = ipField.text;
    
        //change path for caching when IP changed
        if(![lastIP isEqualToString:ipField.text])
        {
            NSString *lastPath = [defaults objectForKey:@"path"];

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
        }
    }
}

//get own IP
- (NSString *)getIPAddress {
    
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
                
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
}

//ping every IP on port 8083 to see if it's a raspberry
- (void)startScan
{
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    
    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
    NSError *error = nil;

    NSString *scanHostIP = [NSString stringWithFormat:@"%@%d", ipRange, count];
    ipField.text = scanHostIP;
    [asyncSocket connectToHost:scanHostIP onPort:PORT withTimeout:0.05 error:&error];
}

//start new connection when the old on failed
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    //count up through all IPs in the subnet
    NSError *error;
    if(count < 254)
    {
        count++;
        NSString *scanHostIP = [NSString stringWithFormat:@"%@%d", ipRange, count];
        ipField.text = scanHostIP;
        [asyncSocket connectToHost:scanHostIP onPort:PORT withTimeout:0.1 error:&error];
    }
    else
    {
        count = 0;
        ipField.text = @"";
    }
}

//if it connected it's a raspberry
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    //set IP in textfield
    count = 0;
    ipField.text = host;
    [ipCheck setImage:[UIImage imageNamed:@"connected.png"]];
    
    NSURL *json_response = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:8083/ZAutomation/api/v1/system/remote-id", host]];
    NSString *json_string = @"";
    json_string = [NSString stringWithFormat:@"%@", json_response ];
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString: json_string]];
    
    __block NSDictionary *json;
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               json = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:nil];
                               if(json != nil)
                               {
                                   NSString *remote_id = @"";
                                   remote_id = [NSString stringWithFormat:@"%@", json[@"data"][@"remote_id"]];
                               
                                   if(remote_id != nil)
                                   {
                                       loginField.text = remote_id;
                                   }
                               }
                           }];
    
    //set SSID
    NSDictionary *SSIDInfo = [self getSSID];
    [[NSUserDefaults standardUserDefaults] setObject:[SSIDInfo objectForKey:@"SSID"] forKey:@"SSID"];
    
    //don't continue
    [sock setDelegate:nil];
    [sock disconnect];
}

@end
