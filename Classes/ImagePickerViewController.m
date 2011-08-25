//
//  ImagePickerViewController.m
//  OpenStack
//
//  Created by Mike Mayo on 10/25/10.
//  The OpenStack project is provided under the Apache 2.0 license.
//

#import "ImagePickerViewController.h"
#import "Image.h"
#import "OpenStackAccount.h"
#import "UIViewController+Conveniences.h"

#define kScaleX .26
//#define kScaleY 1.48148
#define kScaleY 1.38888

@implementation ImagePickerViewController

@synthesize account, tableView;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)groupImages {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:9];
    NSArray *stringKeys = [NSArray arrayWithObjects:@"ubuntu", @"redhat", @"gentoo", @"centos", @"debian", @"windows", @"arch", @"other", @"fedora", nil];
    
    // sort in descending order, since the newest versions are likely the most popular choice
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:nil ascending:NO selector:@selector(compare:)];
    
    for (int i = 0; i < [stringKeys count]; i++) {
        NSString *stringKey = [stringKeys objectAtIndex:i];
        NSArray *keys = [self.account.images allKeys];
        for (int j = 0; j < [keys count]; j++) {
            Image *image = [self.account.images objectForKey:[keys objectAtIndex:j]];
            if ([image respondsToSelector:@selector(logoPrefix)] && [[image logoPrefix] isEqualToString:stringKey]) {
                if (![dict objectForKey:stringKey]) {
                    [dict setObject:[[[NSMutableArray alloc] init] autorelease] forKey:stringKey];
                }
                NSMutableArray *keyedImages = [dict objectForKey:stringKey];
                [keyedImages addObject:image];
                [keyedImages sortUsingSelector:@selector(compare:)];
                [keyedImages sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
            }
        }
    }
    
    [sortDescriptor release];
    images = [[NSDictionary alloc] initWithDictionary:dict];
    [dict release];
    
}


#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
    selectedFamily = @"ubuntu";
    
    [self groupImages];
    
    //UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0.0, -45.0, 320.0, 320.0)];
    UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectMake(-4.0, -89.0, 320.0, 320.0)];
    picker.delegate = self;
    picker.dataSource = self;
    picker.showsSelectionIndicator = NO;
    
    //Resize the picker, rotate it so that it is horizontal and set its position
    CGAffineTransform rotate = picker.transform;
    rotate = CGAffineTransformRotate(rotate, 4.71238898);
    //rotate = CGAffineTransformScale(rotate, .26, 2.25);
    rotate = CGAffineTransformScale(rotate, kScaleX, kScaleY);
    CGAffineTransform t0 = CGAffineTransformMakeTranslation(3, 22.5);
    picker.transform = CGAffineTransformConcat(rotate,t0);
    
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    [self.view addSubview:picker];
    [picker release];
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

#pragma mark -
#pragma mark Table view data source

- (CGFloat)findLabelHeight:(NSString*)text font:(UIFont *)font {
    CGSize textLabelSize = CGSizeMake(260.0, 9000.0f);
    // pad \n\n to fix layout bug
    CGSize stringSize = [text sizeWithFont:font constrainedToSize:textLabelSize lineBreakMode:UILineBreakModeWordWrap];
    return stringSize.height;
}

- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    //CGFloat result = aTableView.rowHeight;
    NSArray *currentImages = [images objectForKey:selectedFamily];
    Image *image = [currentImages objectAtIndex:indexPath.row];    
    CGFloat result = 22.0 + [self findLabelHeight:image.name font:[UIFont boldSystemFontOfSize:18.0]];
    return MAX(aTableView.rowHeight, result);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [[images objectForKey:selectedFamily] count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
        cell.textLabel.backgroundColor = [UIColor clearColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
    }
    
    // Configure the cell...
    NSArray *currentImages = [images objectForKey:selectedFamily];
    Image *image = [currentImages objectAtIndex:indexPath.row];
    cell.textLabel.text = image.name;
    if ([image respondsToSelector:@selector(logoPrefix)]) {
        cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@-icon.png", [image logoPrefix]]];
    } else {
        cell.imageView.image = nil;
    }
	
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark -
#pragma mark Picker View

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 9;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (row == 0) {
        selectedFamily = @"ubuntu";
    } else if (row == 1) {
        selectedFamily = @"redhat";
    } else if (row == 2) {
        selectedFamily = @"gentoo";
    } else if (row == 3) {
        selectedFamily = @"windows";
    } else if (row == 4) {
        selectedFamily = @"debian";
    } else if (row == 5) {
        selectedFamily = @"centos";
    } else if (row == 6) {
        selectedFamily = @"arch";
    } else if (row == 7) {
        selectedFamily = @"fedora";
    } else {
        selectedFamily = @"other";
    }
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    UIView *viewForRow = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 94)] autorelease];
    
    NSString *filename = @"";
    NSString *family = @"";
    
    if (row == 0) {
        filename = @"ubuntu-icon.png";
        family = @"Ubuntu";
    } else if (row == 1) {
        filename = @"redhat-icon.png";
        family = @"Red Hat";
    } else if (row == 2) {
        filename = @"gentoo-icon.png";
        family = @"Gentoo";
    } else if (row == 3) {
        filename = @"windows-icon.png";
        family = @"Windows";
    } else if (row == 4) {
        filename = @"debian-icon.png";
        family = @"Debian";
    } else if (row == 5) {
        filename = @"centos-icon.png";
        family = @"CentOS";
    } else if (row == 6) {
        filename = @"arch-icon.png";
        family = @"Arch";
    } else if (row == 7) {
        filename = @"fedora-icon.png";
        family = @"Fedora";
    } else {
        //filename = @"openstack_icon.png";
        filename = @"cloud-servers-icon.png";
        family = @"Other";
    }
    
    
    
    UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:filename]];
    
    img.frame = CGRectMake(103.0, 0.0, 70.0, 70.0);
    img.opaque = YES;
    [viewForRow addSubview:img];
    [img release];
    
    UILabel *label;
    
    UIFont *font = [UIFont boldSystemFontOfSize:20.0];
    
    label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 70, 278, 35)] autorelease];
    
    label.text = family;
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor blackColor];
    label.font = font;
    label.backgroundColor = [UIColor clearColor];
    label.opaque = NO;
    [viewForRow addSubview:label];
    
    //CGAffineTransform rotate = CGAffineTransformMakeRotation(1.57);  
    //[viewForRow setTransform:rotate]; 
    
    CGAffineTransform rotate = viewForRow.transform;
    rotate = CGAffineTransformRotate(rotate, -4.71238898);
    rotate = CGAffineTransformScale(rotate, kScaleX, kScaleY);
    
    CGAffineTransform t0 = CGAffineTransformMakeTranslation(3, 22.5);
    viewForRow.transform = CGAffineTransformConcat(rotate,t0);
    
    return viewForRow;
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc {
    [account release];
    [tableView release];
    [super dealloc];
}


@end

