/*
 *  GlobeViewController.m
 *  MapBox Earth
 *
 *  Copyright 2013 MapBox & mousebird consulting
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *
 *    Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 *    Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import "GlobeViewController.h"

#import <WhirlyGlobeComponent.h>

#import "AFJSONRequestOperation.h"
#import "UIImageView+AFNetworking.h"

#import <QuartzCore/QuartzCore.h>

@interface GlobeViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UIWebViewDelegate>
{
    WhirlyGlobeViewController *globeViewController;
    MaplyViewControllerLayer *currentLayer;

    NSArray *availableMaps;
    NSInteger selectedMapIndex;
    
    IBOutlet UIButton *slideButton;
    IBOutlet UICollectionView *collectionView;

    UIImageView *logoBug;
}
@end

@implementation GlobeViewController

static NSString *APIPrefix     = @"http://api.tiles.mapbox.com/v3";
static NSString *MapBoxAccount = @"YOUR_ACCOUNT_NAME_HERE";

- (void)viewDidLoad
{
    [super viewDidLoad];

    [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"DefaultCell"];
    collectionView.allowsSelection = YES;
    collectionView.allowsMultipleSelection = NO;
    selectedMapIndex = -1;

    globeViewController = [WhirlyGlobeViewController new];
    [self.view insertSubview:globeViewController.view atIndex:0];
    globeViewController.view.frame = self.view.bounds;
    [self addChildViewController:globeViewController];
    
    // Set the background color for the globe
    globeViewController.clearColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    
    // Start up over DC
    globeViewController.height = 0.8;
    [globeViewController animateToPosition:MaplyCoordinateMakeWithDegrees(-77.032458, 38.913175) time:1.0];

    // Go get the list of available tile sets
    NSString *tileSetList = [NSString stringWithFormat:@"%@/%@/maps.json", APIPrefix, MapBoxAccount];

    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:[NSMutableURLRequest requestWithURL:[NSURL URLWithString:tileSetList]]
                                                                                        success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
                                                                                        {
                                                                                            // We're expecting an array of dictionaries with map info
                                                                                            NSArray *responseArray = (NSArray *)JSON;

                                                                                            if ([responseArray isKindOfClass:[NSArray class]])
                                                                                            {
                                                                                                availableMaps = responseArray;

                                                                                                [collectionView reloadData];

                                                                                                if (selectedMapIndex < 0)
                                                                                                {
                                                                                                    // See if we can find "Afternoon Satellite", otherwise pick 0
                                                                                                    selectedMapIndex = [self findMapNamed:@"Afternoon Satellite"];
                                                                                                    [self pickMap:selectedMapIndex];
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                        failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
                                                                                        {
                                                                                            NSLog(@"Failed to reach tile set list at: %@",tileSetList);
                                                                                        }];
    
    [operation start];

    logoBug = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"mapbox.png"]];
    logoBug.frame = CGRectMake(8, self.view.bounds.size.height - logoBug.bounds.size.height - 4, logoBug.bounds.size.width, logoBug.bounds.size.height);
    logoBug.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.view insertSubview:logoBug belowSubview:collectionView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    collectionView.frame = CGRectMake(collectionView.frame.origin.x,self.view.frame.size.height,collectionView.frame.size.width,collectionView.frame.size.height);    
    slideButton.frame    = CGRectMake(slideButton.frame.origin.x,self.view.frame.size.height-slideButton.frame.size.height,slideButton.frame.size.width,slideButton.frame.size.height);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [collectionView reloadData];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    collectionView.frame = CGRectMake(collectionView.frame.origin.x,self.view.frame.size.height,collectionView.frame.size.width,collectionView.frame.size.height);
    slideButton.frame    = CGRectMake(slideButton.frame.origin.x,self.view.frame.size.height-slideButton.frame.size.height,slideButton.frame.size.width,slideButton.frame.size.height);
}

- (NSUInteger)findMapNamed:(NSString *)name
{
    NSUInteger which, thisOne = 0;

    for (NSDictionary *map in availableMaps)
    {
        if ([map isKindOfClass:[NSDictionary class]])
        {
            NSString *thisName = map[@"name"];

            if ( ! [name compare:thisName])
            {
                which = thisOne;
                break;
            }
        }
        
        thisOne++;
    }
    
    return which;
}

- (void)displayTileSet:(NSString *)tileSetName
{
    // Where we get the overall description of the tiles
    NSString *jsonTileSpec = [NSString stringWithFormat:@"%@/%@.json", APIPrefix, tileSetName];
        
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:[NSMutableURLRequest requestWithURL:[NSURL URLWithString:jsonTileSpec]]
                                                                                        success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
                                                                                        {
                                                                                            if (currentLayer)
                                                                                                [globeViewController removeLayer:currentLayer];

                                                                                            currentLayer = [globeViewController addQuadEarthLayerWithRemoteSource:JSON cache:nil];
                                                                                        }
                                                                                        failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
                                                                                        {
                                                                                            NSLog(@"Failed to reach JSON tile spec at: %@", jsonTileSpec);
                                                                                        }];
    
    [operation start];
}

- (void)pickMap:(NSUInteger)which
{
    if (which >= [availableMaps count])
        return;
    
    NSDictionary *map = availableMaps[which];

    NSString *mapID = map[@"id"];

    if (mapID)
    {
        self.title = map[@"name"];

        [self displayTileSet:mapID];
    }
}

- (IBAction)slideAction:(id)sender
{
    [self slideUp];
}

- (void)slideUp
{
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^(void)
                     {
                         float height = collectionView.frame.size.height;
                         collectionView.frame = CGRectMake(collectionView.frame.origin.x,self.view.frame.size.height-height,
                                                           collectionView.frame.size.width,height);
                         slideButton.alpha = 0.0;
                         slideButton.frame = CGRectMake(slideButton.frame.origin.x,self.view.frame.size.height-height-slideButton.frame.size.height,slideButton.frame.size.width,slideButton.frame.size.height);
                         slideButton.userInteractionEnabled = NO;
                         logoBug.center = CGPointMake(logoBug.center.x, logoBug.center.y - collectionView.bounds.size.height + 10);
                     }
                     completion:^(BOOL finished)
                     {
                         [self performSelector:@selector(slideDown) withObject:nil afterDelay:3.0];
                     }];
}

- (void)slideDown
{
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^(void)
                     {
                         slideButton.alpha = 0.25;
                         slideButton.userInteractionEnabled = YES;
                         collectionView.frame = CGRectMake(collectionView.frame.origin.x,self.view.frame.size.height,
                                                           collectionView.frame.size.width,collectionView.frame.size.height);
                         slideButton.frame = CGRectMake(slideButton.frame.origin.x,self.view.frame.size.height-slideButton.frame.size.height,slideButton.frame.size.width,slideButton.frame.size.height);
                         logoBug.center = CGPointMake(logoBug.center.x, logoBug.center.y + collectionView.bounds.size.height - 10);
                     }
                     completion:nil];
}

- (IBAction)infoAction:(id)sender
{
    UIViewController *webViewController = [UIViewController new];

    webViewController.title = @"MapBox Earth";

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:nil];

    UIWebView *webView = [UIWebView new];
    [webViewController.view addSubview:webView];
    webView.frame = webViewController.view.bounds;
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [webView loadRequest:[NSURLRequest requestWithURL:[[NSBundle mainBundle] URLForResource:@"info" withExtension:@"html"]]];
    webView.delegate = self;

    [self.navigationController pushViewController:webViewController animated:YES];
}

#pragma mark - Collection View Delegate and Data Source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [availableMaps count];
}

static const float InactiveAlpha = 0.5;
static const float ActiveAlpha   = 0.75;

- (UICollectionViewCell *)collectionView:(UICollectionView *)theCollectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [theCollectionView dequeueReusableCellWithReuseIdentifier:@"DefaultCell" forIndexPath:indexPath];

    UIImageView *imageView = [UIImageView new];
    imageView.contentMode = UIViewContentModeScaleToFill;
    imageView.layer.cornerRadius = 9.0;
    imageView.layer.masksToBounds = YES;
    imageView.layer.borderColor = [UIColor grayColor].CGColor;
    imageView.layer.borderWidth = 3.0;
    imageView.frame = cell.contentView.bounds;
    imageView.backgroundColor = [UIColor clearColor];

    cell.backgroundColor = [UIColor clearColor];
    [cell.contentView addSubview:imageView];
    cell.contentView.alpha = InactiveAlpha;

    if (indexPath.row == selectedMapIndex)
    {
        cell.contentView.alpha = ActiveAlpha;
        imageView.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    
    if (indexPath.row < [availableMaps count])
    {
        NSDictionary *mapInfo = [availableMaps objectAtIndex:indexPath.row];

        if ([mapInfo isKindOfClass:[NSDictionary class]])
        {
            NSString *mapId = mapInfo[@"id"];

            if (mapId)
            {
                // Let's ask for that preview image
                NSString *thumbURL = [NSString stringWithFormat:@"%@/%@/thumb.png", APIPrefix, mapId];

                [imageView setImageWithURL:[NSURL URLWithString:thumbURL] placeholderImage:nil];
            }
        }
    }
    
    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == selectedMapIndex)
        return NO;
    
    return YES;
}

- (void)collectionView:(UICollectionView *)theCollectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    int oldSelectedMap = selectedMapIndex;
    [theCollectionView deselectItemAtIndexPath:[NSIndexPath indexPathForRow:selectedMapIndex inSection:0] animated:YES];
    selectedMapIndex = indexPath.row;
    
    [self pickMap:selectedMapIndex];

    [collectionView reloadItemsAtIndexPaths:@[indexPath, [NSIndexPath indexPathForRow:oldSelectedMap inSection:0]]];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    [self performSelector:@selector(slideDown) withObject:nil afterDelay:3.0];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        [[UIApplication sharedApplication] openURL:request.URL];
        
        return NO;
    }
    
    return YES;
}

@end
