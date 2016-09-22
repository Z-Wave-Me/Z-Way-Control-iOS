//
//  AppDelegate.m
//  HA-UI
//
//  Created by Marcel Z-Wave Europe GmbH on 10/12/14.
//  Copyright (c) 2014 Z-Wave Europe GmbH. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

+ (void)initialize {
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //setup app for first use
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *ip = [defaults objectForKey:@"IP"];
    NSString *login = [defaults objectForKey:@"Login"];
    NSString *password = [defaults objectForKey:@"Password"];
    NSString *version = [defaults objectForKey:@"Version"];
    
    if(!version)
        version = @"";
    
    NSString *currentNumber = [[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSString *oldNumber = [version stringByReplacingOccurrencesOfString:@"." withString:@""];
    
    NSInteger current = [currentNumber integerValue];
    NSInteger old = [oldNumber integerValue];
    
    if ((!ip && !login && !password) || [version isEqualToString:@""] || current > old)
        self.window.rootViewController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"WelcomeController"];
    else
        self.window.rootViewController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"WebviewController"];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
