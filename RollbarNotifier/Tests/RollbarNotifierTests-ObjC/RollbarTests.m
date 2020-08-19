//  Copyright (c) 2018 Rollbar, Inc. All rights reserved.

@import Foundation;

#if !TARGET_OS_WATCH
#import <XCTest/XCTest.h>
#import "RollbarTestUtil.h"

@import RollbarNotifier;

@interface RollbarTests : XCTestCase

@end

@implementation RollbarTests

- (void)setUp {
    [super setUp];
    RollbarClearLogFile();
    if (!Rollbar.currentConfiguration) {
        //[Rollbar initWithAccessToken:@""];
        [Rollbar initWithAccessToken:@"2ffc7997ed864dda94f63e7b7daae0f3"];
        Rollbar.currentConfiguration.destination.accessToken = @"2ffc7997ed864dda94f63e7b7daae0f3";
        Rollbar.currentConfiguration.destination.environment = @"unit-tests";
        Rollbar.currentConfiguration.developerOptions.transmit = YES;
        Rollbar.currentConfiguration.developerOptions.logPayload = YES;
        Rollbar.currentConfiguration.loggingOptions.maximumReportsPerMinute = 5000;
    }
}

- (void)tearDown {
    [Rollbar updateConfiguration:[RollbarConfig new]];
    [super tearDown];
}

- (void)testRollbarNotifiersIndependentConfiguration {

    Rollbar.currentConfiguration.developerOptions.transmit = NO;
    Rollbar.currentConfiguration.developerOptions.logPayload = YES;

    // configure the root notifier:
    Rollbar.currentConfiguration.destination.accessToken = @"AT_0";
    Rollbar.currentConfiguration.destination.environment = @"ENV_0";
    
    XCTAssertEqual(Rollbar.currentLogger.configuration.destination.accessToken,
                   Rollbar.currentConfiguration.destination.accessToken);
    XCTAssertEqual(Rollbar.currentLogger.configuration.destination.environment,
                   Rollbar.currentConfiguration.destination.environment);
    
    XCTAssertEqual(Rollbar.currentLogger.configuration.destination.accessToken,
                   Rollbar.currentConfiguration.destination.accessToken);
    XCTAssertEqual(Rollbar.currentLogger.configuration.destination.environment,
                   Rollbar.currentConfiguration.destination.environment);
    
    // create and configure another notifier:
    RollbarLogger *notifier = [[RollbarLogger alloc] initWithAccessToken:@"AT_1"];
    notifier.configuration.destination.environment = @"ENV_1";
    XCTAssertTrue([notifier.configuration.destination.accessToken compare:@"AT_1"] == NSOrderedSame);
    XCTAssertTrue([notifier.configuration.destination.environment compare:@"ENV_1"] == NSOrderedSame);

    // reconfigure the root notifier:
    Rollbar.currentConfiguration.destination.accessToken = @"AT_N";
    Rollbar.currentConfiguration.destination.environment = @"ENV_N";
    XCTAssertTrue([Rollbar.currentLogger.configuration.destination.accessToken compare:@"AT_N"] == NSOrderedSame);
    XCTAssertTrue([Rollbar.currentLogger.configuration.destination.environment compare:@"ENV_N"] == NSOrderedSame);

    // make sure the other notifier is still has its original configuration:
    XCTAssertTrue([notifier.configuration.destination.accessToken compare:@"AT_1"] == NSOrderedSame);
    XCTAssertTrue([notifier.configuration.destination.environment compare:@"ENV_1"] == NSOrderedSame);

    //TODO: to make this test even more valuable we need to make sure the other notifier's payloads
    //      are actually sent to its intended destination. But that is something we will be able to do
    //      once we add to this SDK a feature similar to Rollbar.NET's Internal Events...
}

- (void)testRollbarTransmit {

    Rollbar.currentConfiguration.destination.accessToken = @"2ffc7997ed864dda94f63e7b7daae0f3";
    Rollbar.currentConfiguration.destination.environment = @"unit-tests";
    Rollbar.currentConfiguration.developerOptions.transmit = YES;

    Rollbar.currentConfiguration.developerOptions.transmit = YES;
    [Rollbar critical:@"Transmission test YES"];
    [NSThread sleepForTimeInterval:2.0f];

    Rollbar.currentConfiguration.developerOptions.transmit = NO;
    [Rollbar critical:@"Transmission test NO"];
    [NSThread sleepForTimeInterval:2.0f];

    Rollbar.currentConfiguration.developerOptions.transmit = YES;
    //Rollbar.currentConfiguration.enabled = NO;
    [Rollbar critical:@"Transmission test YES2"];
    [NSThread sleepForTimeInterval:2.0f];
    
    int count = 50;
    while (count > 0) {
        [Rollbar critical:[NSString stringWithFormat: @"Rate Limit Test %i", count]];
         
        [NSThread sleepForTimeInterval:1.0f];
        
        count--;
    }
}

- (void)testNotification {
    NSDictionary *notificationText = @{
                                       @"error": @[@"testing-error-with-message", [NSException exceptionWithName:@"testing-error" reason:@"testing-error-2" userInfo:nil]],
                                       @"debug": @[@"testing-debug"],
                                       @"error": @[@"testing-error"],
                                       @"info": @[@"testing-info"],
                                       @"critical": @[@"testing-critical"]
                                       };
    
    for (NSString *type in notificationText.allKeys) {
        NSArray *params = notificationText[type];
        if ([type isEqualToString:@"error"]) {
            if (params.count == 2) {
                [Rollbar error:params[0] exception:params[1]];
            } else {
                [Rollbar error:params[0]];
            }
        } else if ([type isEqualToString:@"debug"]) {
            [Rollbar debug:params[0]];
        } else if ([type isEqualToString:@"info"]) {
            [Rollbar info:params[0]];
        } else if ([type isEqualToString:@"critical"]) {
            [Rollbar critical:params[0]];
        }
    }

    [NSThread sleepForTimeInterval:3.0f];

    NSArray *items = RollbarReadLogItemFromFile();
    for (id item in items) {
        NSString *level = [item valueForKeyPath:@"level"];
        NSString *message = [item valueForKeyPath:@"body.message.body"];
        NSArray *params = notificationText[level];
        if ([level isEqualToString:@"debug"]) {
            XCTAssertTrue([params[0] isEqualToString:message], @"Expects '%@', got '%@'.", params[0], message);
        } else if ([level isEqualToString:@"error"]) {
            if (params.count == 2) {
                NSException *exception = params[1];
                XCTAssertTrue(exception != nil);
//                NSString *errMsg = [NSString stringWithFormat:@"%@\r\r%@\r\r%@", params[0], exception.reason, [exception.callStackSymbols componentsJoinedByString:@"\n"]];
//                XCTAssertTrue([errMsg isEqualToString:message], @"Expects '%@', got '%@'.", errMsg, message);
            } else {
                XCTAssertTrue([params[0] isEqualToString:message], @"Expects '%@', got '%@'.", params[0], message);
            }
        } else if ([level isEqualToString:@"info"]) {
            XCTAssertTrue([params[0] isEqualToString:message], @"Expects '%@', got '%@'.", params[0], message);
        } else if ([level isEqualToString:@"critical"]) {
            XCTAssertTrue([params[0] isEqualToString:message], @"Expects '%@', got '%@'.", params[0], message);
        }
    }
}

@end
#endif
