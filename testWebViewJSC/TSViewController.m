//
//  TSViewController.m
//  testWebViewJSC
//
//  Created by Nicholas Hodapp on 11/22/13.
//  Copyright (c) 2013 CoDeveloper, LLC. All rights reserved.
//

#import "TSViewController.h"
#import "UIWebView+TS_JavaScriptContext.h"

@protocol JS_TSViewController <JSExport>
- (void) sayGoodbye;
@end

@interface TSViewController () <TSWebViewDelegate, JS_TSViewController>
@end

@implementation TSViewController
{
    IBOutlet UIWebView* _webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSURL* htmlURL = [[NSBundle mainBundle] URLForResource: @"testWebView"
                                             withExtension: @"htm"];
    
    [_webView loadRequest: [NSURLRequest requestWithURL: htmlURL]];
}

- (void)webView:(UIWebView *)webView didCreateJavaScriptContext:(JSContext *)ctx
{
    ctx[@"sayHello"] = ^{
        
        dispatch_async( dispatch_get_main_queue(), ^{
            
            UIAlertView* av = [[UIAlertView alloc] initWithTitle: @"Hello, World!"
                                                         message: nil
                                                        delegate: nil
                                               cancelButtonTitle: @"OK"
                                               otherButtonTitles: nil];
            
            [av show];
        });
    };
    
    ctx[@"viewController"] = self;
}

- (void) sayGoodbye
{
    UIAlertView* av = [[UIAlertView alloc] initWithTitle: @"Goodbye, World!"
                                                 message: nil
                                                delegate: nil
                                       cancelButtonTitle: @"OK"
                                       otherButtonTitles: nil];
    
    [av show];
}

@end
