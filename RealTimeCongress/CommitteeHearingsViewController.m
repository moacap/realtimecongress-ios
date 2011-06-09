//
//  CommitteeHearingsViewController.m
//  RealTimeCongress
//
//  Created by Tom Tsai on 5/25/11.
//  Copyright 2011 Sunlight Labs. All rights reserved.
//

#import "CommitteeHearingsViewController.h"
#import "JSONKit.h"

#pragma mark Utility extensions

@interface UILabel (sizingExtensions)
- (void)sizeToFitFixedWidth:(NSInteger)fixedWidth;
@end

@implementation UILabel (sizingExtensions)


- (void)sizeToFitFixedWidth:(NSInteger)fixedWidth
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, fixedWidth, 0);
    self.lineBreakMode = UILineBreakModeWordWrap;
    self.numberOfLines = 0;
    [self sizeToFit];
}
@end

@implementation CommitteeHearingsViewController

@synthesize parsedHearingData;
@synthesize items;
@synthesize jsonData;
@synthesize jsonKitDecoder;
@synthesize chamberControl;
@synthesize hearingEnumerator;
@synthesize allHearings;
@synthesize loadingIndicator;
@synthesize opQueue;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
    [loadingIndicator release];
    [chamberControl release];
    [opQueue release];
    [parsedHearingData release];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
    [parsedHearingData release];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self  action:@selector(refresh)];
    self.navigationItem.rightBarButtonItem = refreshButton;
    
    //Make cells unselectable
    self.tableView.allowsSelection = NO;
    
    //Initialize the operation queue
    opQueue = [[NSOperationQueue alloc] init];
    
    // Refreshes table view data on segmented control press;
    [chamberControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    //An activity indicator to indicate loading
    loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingIndicator setCenter:self.view.center];
    [self.view addSubview:loadingIndicator];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //Refresh data
    [self refresh];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (parsedHearingData != NULL) {
        return [parsedHearingData count];
    }
    else{
        return 20;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Create a custom cell for each entry. Set the height according to string length or autosize.
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
    cell.textLabel.text                      = [[[parsedHearingData objectAtIndex:indexPath.row] 
                                                objectForKey:@"committee"] objectForKey:@"name"];
    cell.detailTextLabel.text                = [[parsedHearingData objectAtIndex:indexPath.row] 
                                                objectForKey:@"legislative_day"];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    
    return cell;

}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 45;
}

#pragma mark - UI Actions
- (void) refresh
{
    //Set the navigation bar title to that of the selected chamber
    self.title = [NSString stringWithFormat:@"%@ Hearings", [chamberControl titleForSegmentAtIndex:chamberControl.selectedSegmentIndex]];
    
    //Animate the activity indicator when loading data
    [self.loadingIndicator startAnimating];
    
    //Asynchronously retrieve data
    NSInvocationOperation* dataRetrievalOp = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                                   selector:@selector(retrieveData) object:nil] autorelease];
    [dataRetrievalOp addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    [opQueue addOperation:dataRetrievalOp];
}

- (void) parseData
{
    jsonKitDecoder = [JSONDecoder decoder];
    items = [jsonKitDecoder objectWithData:jsonData];
    NSArray *data = [items objectForKey:@"committee_hearings"];

    //Sort data by legislative day
    NSSortDescriptor *sortByDate = [NSSortDescriptor sortDescriptorWithKey:@"legislative_day" ascending:YES];
    NSArray *descriptors = [[NSArray alloc] initWithObjects: sortByDate, nil];
    parsedHearingData = [[NSArray alloc] initWithArray:[data sortedArrayUsingDescriptors:descriptors]];
    
}

- (void) retrieveData
{
    //JSONKit requests
    //Request data based on segemented control selection
    if (chamberControl.selectedSegmentIndex == 0) {
        jsonData = [NSData dataWithContentsOfURL:[NSURL URLWithString:HOUSE_URL]];
    }
    else {
        jsonData = [NSData dataWithContentsOfURL:[NSURL URLWithString:SENATE_URL]];
    }
    if (jsonData != NULL) {
        [self parseData];
    }
}

#pragma mark Key-Value Observing methods
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqual:@"isFinished"]) {
        //Reload the table once data retrieval is complete
        [self.tableView reloadData];
            
        //Hide the activity indicator once loading is complete
        [loadingIndicator stopAnimating];
    }
}

@end
