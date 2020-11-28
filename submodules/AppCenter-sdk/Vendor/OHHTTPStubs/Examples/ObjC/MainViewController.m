//
//  MainViewController.m
//  OHHTTPStubsDemo
//
//  Created by Olivier Halligon on 11/08/12.
//  Copyright (c) 2012 AliSoftware. All rights reserved.
//

#import "MainViewController.h"
#import <OHHTTPStubs/HTTPStubs.h>
#import <OHHTTPStubs/HTTPStubsPathHelpers.h>


@interface MainViewController ()
// IBOutlets
@property (retain, nonatomic) IBOutlet UISwitch *delaySwitch;
@property (retain, nonatomic) IBOutlet UITextView *textView;
@property (retain, nonatomic) IBOutlet UISwitch *installTextStubSwitch;
@property (retain, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) IBOutlet UISwitch *installImageStubSwitch;
@end

@implementation MainViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Init & Dealloc

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self installTextStub:self.installTextStubSwitch];
    [self installImageStub:self.installImageStubSwitch];
    [HTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<HTTPStubsDescriptor>  _Nonnull stub, HTTPStubsResponse * _Nonnull responseStub) {
        NSLog(@"[OHHTTPStubs] Request to %@ has been stubbed with %@", request.URL, stub.name);
    }];
}

- (BOOL)shouldUseDelay {
  __block BOOL res = NO;
  dispatch_sync(dispatch_get_main_queue(), ^{
    res = self.delaySwitch.on;
  });
  return res;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Global stubs activation

- (IBAction)toggleStubs:(UISwitch *)sender
{
    [HTTPStubs setEnabled:sender.on];
    self.delaySwitch.enabled = sender.on;
    self.installTextStubSwitch.enabled = sender.on;
    self.installImageStubSwitch.enabled = sender.on;
    
    NSLog(@"Installed (%@) stubs: %@", (sender.on?@"and enabled":@"but disabled"), HTTPStubs.allStubs);
}




////////////////////////////////////////////////////////////////////////////////
#pragma mark - Text Download and Stub


- (IBAction)downloadText:(UIButton*)sender
{
    sender.enabled = NO;
    self.textView.text = nil;

    NSString* urlString = @"http://www.opensource.apple.com/source/Git/Git-26/src/git-htmldocs/git-commit.txt?txt";
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    // This is a very handy way to send an asynchronous method, but only available in iOS5+
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse* resp, NSData* data, NSError* error)
     {
         sender.enabled = YES;
         NSString* receivedText = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
         self.textView.text = receivedText;
     }];
}




- (IBAction)installTextStub:(UISwitch *)sender
{
    static id<HTTPStubsDescriptor> textStub = nil; // Note: no need to retain this value, it is retained by the OHHTTPStubs itself already
    if (sender.on)
    {
        // Install
        textStub = [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            // This stub will only configure stub requests for "*.txt" files
            return [request.URL.pathExtension isEqualToString:@"txt"];
        } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
            // Stub txt files with this
            return [[HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"stub.txt", self.class)
                                                     statusCode:200
                                                        headers:@{@"Content-Type":@"text/plain"}]
                    requestTime:[self shouldUseDelay] ? 2.f: 0.f
                    responseTime:OHHTTPStubsDownloadSpeedWifi];
        }];
        textStub.name = @"Text stub";
    }
    else
    {
        // Uninstall
        [HTTPStubs removeStub:textStub];
    }
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark - Image Download and Stub

- (IBAction)downloadImage:(UIButton*)sender
{
    sender.enabled = NO;
    
    NSString* urlString = @"http://images.apple.com/support/assets/images/products/iphone/hero_iphone4-5_wide.png";
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    // This is a very handy way to send an asynchronous method, but only available in iOS5+
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse* resp, NSData* data, NSError* error)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
            sender.enabled = YES;
            self.imageView.image = [UIImage imageWithData:data];
         });
     }];
}

- (IBAction)installImageStub:(UISwitch *)sender
{
    static id<HTTPStubsDescriptor> imageStub = nil; // Note: no need to retain this value, it is retained by the OHHTTPStubs itself already :)
    if (sender.on)
    {
        // Install
        imageStub = [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            // This stub will only configure stub requests for "*.png" files
            return [request.URL.pathExtension isEqualToString:@"png"];
        } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
            // Stub jpg files with this
            return [[HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"stub.jpg", self.class)
                                                     statusCode:200
                                                        headers:@{@"Content-Type":@"image/jpeg"}]
                    requestTime:[self shouldUseDelay] ? 2.f: 0.f
                    responseTime:OHHTTPStubsDownloadSpeedWifi];
        }];
        imageStub.name = @"Image stub";
    }
    else
    {
        // Uninstall
        [HTTPStubs removeStub:imageStub];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Cleaning

- (IBAction)clearResults
{
    self.textView.text = @"";
    self.imageView.image = nil;
}

@end

