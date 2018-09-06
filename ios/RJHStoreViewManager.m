#import <TargetConditionals.h>
#import "RJHStoreViewManager.h"
#import <React/RCTUtils.h>
#import <React/RCTLog.h>

@implementation RJHStoreViewManager

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

RCT_EXPORT_METHOD(loadProductWithParameters:(NSDictionary *)args callback: (RCTResponseSenderBlock)callback)
{
    NSError *error = nil;
    NSDictionary* nativeParams = [self transformAndValidateLoadProductParamaters:args error:&error];

    if (nativeParams == nil) {
        return callback(@[error.userInfo]);
    }

#if TARGET_IPHONE_SIMULATOR
    return callback(@[RCTMakeError(@"ReactNativeStoreView cannot be used in a Simulator.", error, args)]);
#endif

    // Initialize the Store Product View
    self.storeProductView = [[SKStoreProductViewController alloc] init];
    self.storeProductView.delegate = self;

    [self sendEventWithNameIfListening:@"RJHStoreViewManagerLoading" body:nil];

    [self.storeProductView loadProductWithParameters: nativeParams completionBlock:^(BOOL result, NSError *error) {
        if (!result) {
            if (error) {
                callback(@[RCTMakeError(@"Failed to load product.", error, args)]);
            } else {
                callback(@[RCTMakeError(@"Unknown error loading product.", nil, args)]);
            }
        } else {
            [self sendEventWithNameIfListening:@"RJHStoreViewManagerLoaded" body:nil];
            callback(@[[NSNull null]]);
        }
    }];
}

RCT_EXPORT_METHOD(presentViewController: (BOOL)animated callback: (RCTResponseSenderBlock)callback)
{
    UIViewController *rootViewController = RCTPresentedViewController();
    [self sendEventWithNameIfListening:@"RJHStoreViewManagerPresenting" body:nil];
    [rootViewController presentViewController:self.storeProductView animated:animated completion:^() {
        [self sendEventWithNameIfListening:@"RJHStoreViewManagerPresented" body:nil];
        if (callback != nil) {
            callback(@[[NSNull null]]);
        }
    }];
}

RCT_EXPORT_METHOD(isAvailable:(nonnull RCTResponseSenderBlock)callback)
{
    if ([SKStoreProductViewController class]) {
        // SKStoreProductViewController is available
        callback(@[[NSNull null], @YES]);
    } else {
        callback(@[[NSNull null], @NO]);
    }
}

-(void)sendEventWithNameIfListening: (NSString *) name body:(id)body
{
    if (self.hasListeners) {
        [self sendEventWithName:name body:body];
    }
}

RCT_EXPORT_METHOD(dismiss: (BOOL)animated callback: (RCTResponseSenderBlock)callback)
{
    [self.storeProductView dismissViewControllerAnimated:animated completion:^{
        [self sendEventWithNameIfListening:@"RJHStoreViewManagerDismissed" body:@{@"dismissedByUser": @NO}];
        if (callback != nil) {
            callback(@[[NSNull null]]);
        }
    }];

    if (self.hasListeners) {
        [self sendEventWithNameIfListening:@"RJHStoreViewManagerDismissing" body:@{@"dismissedByUser": @NO}];
    }
}

-(void)productViewControllerDidFinish:(nonnull SKStoreProductViewController *)controller
{
    [controller dismissViewControllerAnimated:true completion:^{
        [self sendEventWithNameIfListening:@"RJHStoreViewManagerDismissed" body:@{@"dismissedByUser": @YES}];
    }];

    [self sendEventWithNameIfListening:@"RJHStoreViewManagerDismissing" body:@{@"dismissedByUser": @YES}];
}

-(NSDictionary *)transformAndValidateLoadProductParamaters:(nonnull NSDictionary *)args error:(NSError **)errorPtr
{
    //Validate args
    if ([args objectForKey:@"iTunesItemIdentifier"] == nil ||
        ![[args objectForKey:@"iTunesItemIdentifier"] isKindOfClass:[NSNumber class]]) {
        *errorPtr = [NSError errorWithDomain:@"ReactNativeStoreView"
                                        code:400
                                    userInfo:RCTMakeError(@"Must specify an iTunesItemIdentifier as a number", nil, args)];
        return nil;
    }

    NSMutableDictionary* nativeParams = [[NSMutableDictionary alloc] initWithCapacity:4];

    [nativeParams setObject: [args objectForKey:@"iTunesItemIdentifier"] forKey: SKStoreProductParameterITunesItemIdentifier];

    if ([args objectForKey:@"affiliateToken"] != nil && [[args objectForKey:@"affiliateToken"] isKindOfClass:[NSString class]]) {
        if (@available(iOS 8.0, *)) {
            [nativeParams setObject: [args objectForKey:@"affiliateToken"] forKey: SKStoreProductParameterAffiliateToken];
        } else {
            RCTLogInfo(@"[ReactNativeStoreView] affiliateToken is not supported on iOS < 8.0. Ignoring");
        }
    }

    if ([args objectForKey:@"campaignToken"] != nil && [[args objectForKey:@"campaignToken"] isKindOfClass:[NSString class]]) {
        if (@available(iOS 8.0, *)) {
            [nativeParams setObject: [args objectForKey:@"campaignToken"] forKey: SKStoreProductParameterCampaignToken];
        } else {
            RCTLogInfo(@"[ReactNativeStoreView] campaignToken is not supported on iOS < 8.0. Ignoring");
        }
    }

    if ([args objectForKey:@"providerToken"] != nil && [[args objectForKey:@"providerToken"] isKindOfClass:[NSString class]]) {
        if (@available(iOS 8.3, *)) {
            [nativeParams setObject: [args objectForKey:@"providerToken"] forKey: SKStoreProductParameterProviderToken];
        } else {
            RCTLogInfo(@"[ReactNativeStoreView] providerToken is not supported on iOS < 8.3. Ignoring");
        }
    }

    if ([args objectForKey:@"advertisingPartnerToken"] != nil && [[args objectForKey:@"advertisingPartnerToken"] isKindOfClass:[NSString class]]) {
        if (@available(iOS 9.3, *)) {
            [nativeParams setObject: [args objectForKey:@"advertisingPartnerToken"] forKey: SKStoreProductParameterAdvertisingPartnerToken];
        } else {
            RCTLogInfo(@"[ReactNativeStoreView] advertisingPartnerToken is not supported on iOS < 9.3. Ignoring");
        }
    }

    return nativeParams;
}

-(void)startObserving {
    self.hasListeners = YES;
}

-(void)stopObserving {
    self.hasListeners = NO;
}

-(NSArray<NSString *> *)supportedEvents {
    return @[@"RJHStoreViewManagerLoading",
             @"RJHStoreViewManagerLoaded",
             @"RJHStoreViewManagerPresenting",
             @"RJHStoreViewManagerPresented",
             @"RJHStoreViewManagerDismissing",
             @"RJHStoreViewManagerDismissed"
             ];
}

@end
