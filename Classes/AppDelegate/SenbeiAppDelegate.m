//
//  SaccharinAppDelegate.m
//  Saccharin
//
//  Created by Adrian on 1/19/10.
//  Copyright akosma software 2010. All rights reserved.
//

#import "SaccharinAppDelegate.h"
#import "ListController.h"
#import "SettingsController.h"
#import "CommentsController.h"
#import "TasksController.h"
#import "FatFreeCRMProxy.h"
#import "CompanyAccount.h"
#import "Opportunity.h"
#import "Contact.h"
#import "User.h"
#import "Campaign.h"
#import "Lead.h"
#import "WebBrowserController.h"
#import "Definitions.h"

#define TAB_ORDER_PREFERENCE @"TAB_ORDER_PREFERENCE"
#define CURRENT_TAB_PREFERENCE @"CURRENT_TAB_PREFERENCE"

NSString *getValueForPropertyFromPerson(ABRecordRef person, ABPropertyID property, ABMultiValueIdentifier identifierForValue)
{
    ABMultiValueRef items = ABRecordCopyValue(person, property);
    NSString *value = (NSString *)ABMultiValueCopyValueAtIndex(items, identifierForValue);
    CFRelease(items);
    return [value autorelease];
}

@implementation SaccharinAppDelegate

@synthesize currentUser = _currentUser;

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:_accountsController];
    [_commentsController release];
    [_currentUser release];
    [super dealloc];
}

#pragma mark -
#pragma mark Static methods

+ (SaccharinAppDelegate *)sharedAppDelegate
{
    return (SaccharinAppDelegate *)[UIApplication sharedApplication].delegate;
}

#pragma mark -
#pragma mark UIApplicationDelegate methods

- (void)applicationDidFinishLaunching:(UIApplication *)application 
{
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didLogin:) 
                                                 name:FatFreeCRMProxyDidLoginNotification
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didFailWithError:) 
                                                 name:FatFreeCRMProxyDidFailWithErrorNotification 
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];

    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didFailLogin:) 
                                                 name:FatFreeCRMProxyDidFailLoginNotification 
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];
    
    [[FatFreeCRMProxy sharedFatFreeCRMProxy] login];
    
    // Set some defaults for the first run of the application
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults stringForKey:PREFERENCES_SERVER_URL] == nil)
    {
        [defaults setObject:@"http://demo.fatfreecrm.com" forKey:PREFERENCES_SERVER_URL];
    }
    if ([defaults stringForKey:PREFERENCES_USERNAME] == nil || [defaults stringForKey:PREFERENCES_PASSWORD] == nil)
    {
        // Use a random username from those used in the Fat Free CRM wiki
        // http://wiki.github.com/michaeldv/fat_free_crm/loading-demo-data
        NSString *path = [[NSBundle mainBundle] pathForResource:@"DemoLogins" ofType:@"plist"];
        NSArray *usernames = [NSArray arrayWithContentsOfFile:path];
        NSInteger index = floor(arc4random() % [usernames count]);
        NSString *username = [usernames objectAtIndex:index];
        [defaults setObject:username forKey:PREFERENCES_USERNAME];
        [defaults setObject:username forKey:PREFERENCES_PASSWORD];
    }
    [defaults synchronize];
    
    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:PREFERENCES_USERNAME];
    _statusLabel.text = [NSString stringWithFormat:@"Logging in as %@...", username];

    [_window makeKeyAndVisible];
}

#pragma mark -
#pragma mark NSNotification handler methods

- (void)didFailLogin:(NSNotification *)notification
{
    [_spinningWheel stopAnimating];
    _statusLabel.text = @"Failed login";

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil 
                                                    message:@"The server rejected your credentials"
                                                   delegate:nil 
                                          cancelButtonTitle:@"OK" 
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

- (void)didFailWithError:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSError *error = [userInfo objectForKey:FatFreeCRMProxyErrorKey];
    NSString *msg = [error localizedDescription];

    [_spinningWheel stopAnimating];
    _statusLabel.text = [NSString stringWithFormat:@"Error! (code %d)", [error code]];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil 
                                                    message:msg 
                                                   delegate:nil 
                                          cancelButtonTitle:@"OK" 
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

- (void)didLogin:(NSNotification *)notification
{
    _currentUser = [[[notification userInfo] objectForKey:@"user"] retain];
    _statusLabel.text = @"Loading controllers...";

    [[NSNotificationCenter defaultCenter] addObserver:_accountsController 
                                             selector:@selector(didReceiveData:) 
                                                 name:FatFreeCRMProxyDidRetrieveAccountsNotification
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];
    _accountsController.listedClass = [CompanyAccount class];
    
    [[NSNotificationCenter defaultCenter] addObserver:_opportunitiesController 
                                             selector:@selector(didReceiveData:) 
                                                 name:FatFreeCRMProxyDidRetrieveOpportunitiesNotification
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];
    _opportunitiesController.listedClass = [Opportunity class];
    
    [[NSNotificationCenter defaultCenter] addObserver:_contactsController 
                                             selector:@selector(didReceiveData:) 
                                                 name:FatFreeCRMProxyDidRetrieveContactsNotification
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];
    _contactsController.listedClass = [Contact class];
    _contactsController.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

    [[NSNotificationCenter defaultCenter] addObserver:_campaignsController
                                             selector:@selector(didReceiveData:)
                                                 name:FatFreeCRMProxyDidRetrieveCampaignsNotification
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];
    _campaignsController.listedClass = [Campaign class];

    [[NSNotificationCenter defaultCenter] addObserver:_leadsController
                                             selector:@selector(didReceiveData:)
                                                 name:FatFreeCRMProxyDidRetrieveLeadsNotification
                                               object:[FatFreeCRMProxy sharedFatFreeCRMProxy]];
    _leadsController.listedClass = [Lead class];
    
    _leadsController.tabBarItem.image = [UIImage imageNamed:@"leads.png"];
    _contactsController.tabBarItem.image = [UIImage imageNamed:@"contacts.png"];
    _campaignsController.tabBarItem.image = [UIImage imageNamed:@"campaigns.png"];
    _tasksController.tabBarItem.image = [UIImage imageNamed:@"tasks.png"];
    _accountsController.tabBarItem.image = [UIImage imageNamed:@"accounts.png"];
    _opportunitiesController.tabBarItem.image = [UIImage imageNamed:@"opportunities.png"];
    
    // Restore the order of the tab bars following the preferences of the user
    NSArray *order = [[NSUserDefaults standardUserDefaults] objectForKey:TAB_ORDER_PREFERENCE];
    NSMutableArray *controllers = [[NSMutableArray alloc] initWithCapacity:7];
    if (order == nil)
    {
        // Probably first run, or never reordered controllers
        [controllers addObject:_accountsController.navigationController];
        [controllers addObject:_contactsController.navigationController];
        [controllers addObject:_opportunitiesController.navigationController];
        [controllers addObject:_tasksController.navigationController];
        [controllers addObject:_leadsController.navigationController];
        [controllers addObject:_campaignsController.navigationController];
        [controllers addObject:_settingsController.navigationController];
    }
    else 
    {
        for (id number in order)
        {
            switch ([number intValue]) 
            {
                case SaccharinViewControllerAccounts:
                    [controllers addObject:_accountsController.navigationController];
                    break;

                case SaccharinViewControllerCampaigns:
                    [controllers addObject:_campaignsController.navigationController];
                    break;

                case SaccharinViewControllerContacts:
                    [controllers addObject:_contactsController.navigationController];
                    break;

                case SaccharinViewControllerLeads:
                    [controllers addObject:_leadsController.navigationController];
                    break;

                case SaccharinViewControllerOpportunities:
                    [controllers addObject:_opportunitiesController.navigationController];
                    break;

                case SaccharinViewControllerSettings:
                    [controllers addObject:_settingsController.navigationController];
                    break;

                case SaccharinViewControllerTasks:
                    [controllers addObject:_tasksController.navigationController];
                    break;
                default:
                    break;
            }
        }
    }

    _tabBarController.viewControllers = controllers;
    [controllers release];
    
    // Jump to the last selected view controller in the tab bar
    SaccharinViewController controllerNumber = [[NSUserDefaults standardUserDefaults] integerForKey:CURRENT_TAB_PREFERENCE];
    switch (controllerNumber) 
    {
        case SaccharinViewControllerAccounts:
            _tabBarController.selectedViewController = _accountsController.navigationController;
            break;
            
        case SaccharinViewControllerCampaigns:
            _tabBarController.selectedViewController = _campaignsController.navigationController;
            break;
            
        case SaccharinViewControllerContacts:
            _tabBarController.selectedViewController = _contactsController.navigationController;
            break;
            
        case SaccharinViewControllerLeads:
            _tabBarController.selectedViewController = _leadsController.navigationController;
            break;
            
        case SaccharinViewControllerOpportunities:
            _tabBarController.selectedViewController = _opportunitiesController.navigationController;
            break;
            
        case SaccharinViewControllerSettings:
            _tabBarController.selectedViewController = _settingsController.navigationController;
            break;
            
        case SaccharinViewControllerTasks:
            _tabBarController.selectedViewController = _tasksController.navigationController;
            break;
            
        case SaccharinViewControllerMore:
            _tabBarController.selectedViewController = _tabBarController.moreNavigationController;
        default:
            break;
    }

    [_window addSubview:_tabBarController.view];
}

#pragma mark -
#pragma mark UITabBarControllerDelegate methods

- (void)tabBarController:(UITabBarController *)tabBarController 
 didSelectViewController:(UIViewController *)viewController
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (viewController == _accountsController.navigationController)
    {
        [defaults setInteger:SaccharinViewControllerAccounts forKey:CURRENT_TAB_PREFERENCE];
    }
    else if (viewController == _contactsController.navigationController)
    {
        [defaults setInteger:SaccharinViewControllerContacts forKey:CURRENT_TAB_PREFERENCE];
    }
    else if (viewController == _opportunitiesController.navigationController)
    {
        [defaults setInteger:SaccharinViewControllerOpportunities forKey:CURRENT_TAB_PREFERENCE];
    }
    else if (viewController == _tasksController.navigationController)
    {
        [defaults setInteger:SaccharinViewControllerTasks forKey:CURRENT_TAB_PREFERENCE];
    }
    else if (viewController == _leadsController.navigationController)
    {
        [defaults setInteger:SaccharinViewControllerLeads forKey:CURRENT_TAB_PREFERENCE];
    }
    else if (viewController == _campaignsController.navigationController)
    {
        [defaults setInteger:SaccharinViewControllerCampaigns forKey:CURRENT_TAB_PREFERENCE];
    }
    else if (viewController == _settingsController.navigationController)
    {
        [defaults setInteger:SaccharinViewControllerSettings forKey:CURRENT_TAB_PREFERENCE];
    }
    else if (viewController == _tabBarController.moreNavigationController)
    {
        [defaults setInteger:SaccharinViewControllerMore forKey:CURRENT_TAB_PREFERENCE];
    }
}

-         (void)tabBarController:(UITabBarController *)tabBarController 
didEndCustomizingViewControllers:(NSArray *)viewControllers 
                         changed:(BOOL)changed
{
    if (changed)
    {
        NSMutableArray *order = [[NSMutableArray alloc] initWithCapacity:7];
        for (id controller in viewControllers)
        {
            if (controller == _accountsController.navigationController)
            {
                [order addObject:[NSNumber numberWithInt:SaccharinViewControllerAccounts]];
            }
            else if (controller == _contactsController.navigationController)
            {
                [order addObject:[NSNumber numberWithInt:SaccharinViewControllerContacts]];
            }
            else if (controller == _opportunitiesController.navigationController)
            {
                [order addObject:[NSNumber numberWithInt:SaccharinViewControllerOpportunities]];
            }
            else if (controller == _tasksController.navigationController)
            {
                [order addObject:[NSNumber numberWithInt:SaccharinViewControllerTasks]];
            }
            else if (controller == _leadsController.navigationController)
            {
                [order addObject:[NSNumber numberWithInt:SaccharinViewControllerLeads]];
            }
            else if (controller == _campaignsController.navigationController)
            {
                [order addObject:[NSNumber numberWithInt:SaccharinViewControllerCampaigns]];
            }
            else if (controller == _settingsController.navigationController)
            {
                [order addObject:[NSNumber numberWithInt:SaccharinViewControllerSettings]];
            }
        }
        [[NSUserDefaults standardUserDefaults] setObject:order forKey:TAB_ORDER_PREFERENCE];
        [order release];
    }
}

#pragma mark -
#pragma mark BaseListControllerDelegate methods

- (void)listController:(ListController *)controller didSelectEntity:(BaseEntity *)entity
{
    if (controller == _contactsController)
    {
        ABPersonViewController *personController = [[ABPersonViewController alloc] init];
        Contact *contact = (Contact *)entity;
        ABRecordRef person = contact.person;
        personController.displayedPerson = person;
        personController.displayedProperties = [Contact displayedProperties];
        personController.personViewDelegate = self;
        [controller.navigationController pushViewController:personController animated:YES];
        [personController release];
    }
    else
    {
        if (_commentsController == nil)
        {
            _commentsController = [[CommentsController alloc] init];
        }
        _commentsController.entity = entity;
        [controller.navigationController pushViewController:_commentsController animated:YES];
    }
}

- (void)listController:(ListController *)controller didTapAccessoryForEntity:(BaseEntity *)entity
{
    if (controller == _contactsController)
    {
        if (_commentsController == nil)
        {
            _commentsController = [[CommentsController alloc] init];
        }
        _commentsController.entity = entity;
        [controller.navigationController pushViewController:_commentsController animated:YES];
    }
}

#pragma mark -
#pragma mark ABPersonViewControllerDelegate methods

-        (BOOL)personViewController:(ABPersonViewController *)personViewController 
shouldPerformDefaultActionForPerson:(ABRecordRef)person 
                           property:(ABPropertyID)property 
                         identifier:(ABMultiValueIdentifier)identifierForValue
{
    if (property == kABPersonEmailProperty)
    {
        NSString* email = getValueForPropertyFromPerson(person, property, identifierForValue);
        MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
        composer.mailComposeDelegate = self;
        [composer setToRecipients:[NSArray arrayWithObject:email]];

        [composer setMessageBody:@"<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>Sent from Saccharin</p>" 
                          isHTML:YES];                    
        
        [personViewController presentModalViewController:composer animated:YES];
        [composer release];
        return NO;
    }
    else if (property == kABPersonURLProperty)
    {
        NSString* urlString = getValueForPropertyFromPerson(person, property, identifierForValue);
        NSURL *url = [[NSURL alloc] initWithString:urlString];
        WebBrowserController *webController = [[WebBrowserController alloc] init];
        webController.url = url;
        webController.title = urlString;
        webController.hidesBottomBarWhenPushed = YES;
        [personViewController presentModalViewController:webController animated:YES];
        [webController release];
        [url release];
        return NO;
    }

    return YES;
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate methods

- (void)mailComposeController:(MFMailComposeViewController*)controller 
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError*)err
{
    [controller dismissModalViewControllerAnimated:YES];
}

@end