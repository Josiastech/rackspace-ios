//
//  ReferrerACLViewController.m
//  OpenStack
//
//  Created by Mike Mayo on 12/31/10.
//  The OpenStack project is provided under the Apache 2.0 license.
//

#import "ReferrerACLViewController.h"
#import "OpenStackAccount.h"
#import "Container.h"
#import "UIViewController+Conveniences.h"
#import "RSTextFieldCell.h"
#import "ActivityIndicatorView.h"
#import "AccountManager.h"
#import "ContainerDetailViewController.h"


@implementation ReferrerACLViewController

@synthesize account, container, containerDetailViewController;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addSaveButton];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self addCancelButton];
    }
    self.navigationItem.title = @"Referrer ACL";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	[textField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.containerDetailViewController.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:4] animated:YES];
    }
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"The Referrer ACL is a Perl Compatible Regular Expression that must match the referrer for all content requests.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ReferrerACLCell";
    RSTextFieldCell *cell = (RSTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[RSTextFieldCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
        cell.modalPresentationStyle = UIModalPresentationFormSheet;
		textField = cell.textField;
		textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.delegate = self;
		
        CGRect rect = CGRectInset(cell.contentView.bounds, 23.0, 12);
        rect.size.height += 5; // make slightly taller to not clip the bottom of text
        textField.frame = rect;
    }    
    cell.textLabel.text = @"";
    textField.text = container.referrerACL;
    return cell;
}

#pragma mark - TextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self saveButtonPressed:nil];
    return NO;
}

#pragma mark - Save Button

- (void)saveButtonPressed:(id)sender {
    NSString *oldACL = container.referrerACL;
    NSString *activityMessage = @"Saving...";
    activityIndicatorView = [[ActivityIndicatorView alloc] initWithFrame:[ActivityIndicatorView frameForText:activityMessage] text:activityMessage];
    [activityIndicatorView addToView:self.view];
    container.referrerACL = textField.text;

    [[self.account.manager updateCDNContainer:container] success:^(OpenStackRequest *request) {
        
        [containerDetailViewController.tableView reloadData];
        [activityIndicatorView removeFromSuperviewAndRelease];
        [textField resignFirstResponder];
        [self.navigationController popViewControllerAnimated:YES];

    } failure:^(OpenStackRequest *request) {
        
        [activityIndicatorView removeFromSuperviewAndRelease];
        container.referrerACL = oldACL;
        textField.text = oldACL;
        [self alert:@"There was a problem updating this container." request:request];

    }];
    
}

#pragma mark - Memory management

- (void)dealloc {
    [account release];
    [container release];
    [containerDetailViewController release];
    [super dealloc];
}

@end
