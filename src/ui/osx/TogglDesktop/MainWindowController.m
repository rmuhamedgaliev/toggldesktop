//
//  MainWindowController.m
//  Toggl Desktop on the Mac
//
//  Created by Tambet Masik on 9/24/13.
//  Copyright (c) 2013 TogglDesktop developers. All rights reserved.
//

#import "MainWindowController.h"
#import "LoginViewController.h"
#import "TimeEntryListViewController.h"
#import "OverlayViewController.h"
#import "TimeEntryViewItem.h"
#import "UIEvents.h"
#import "MenuItemTags.h"
#import "DisplayCommand.h"
#include <Carbon/Carbon.h>
#import "TrackingService.h"
#import "TogglDesktop-Swift.h"

@interface MainWindowController ()
@property (nonatomic, strong) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, strong) IBOutlet TimeEntryListViewController *timeEntryListViewController;
@property (nonatomic, strong) IBOutlet OverlayViewController *overlayViewController;
@property double troubleBoxDefaultHeight;
@property (nonatomic, strong) SystemMessageView *messageView;

@end

@implementation MainWindowController

extern void *ctx;

- (id)initWithWindow:(NSWindow *)window
{
	self = [super initWithWindow:window];
	if (self)
	{
		self.loginViewController = [[LoginViewController alloc]
									initWithNibName:@"LoginViewController" bundle:nil];
		self.timeEntryListViewController = [[TimeEntryListViewController alloc]
											initWithNibName:@"TimeEntryListViewController" bundle:nil];
		self.overlayViewController = [[OverlayViewController alloc]
									  initWithNibName:@"OverlayViewController" bundle:nil];


		[self.loginViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self.timeEntryListViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self.overlayViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(startDisplayLogin:)
													 name:kDisplayLogin
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(startDisplayTimeEntryList:)
													 name:kDisplayTimeEntryList
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(startDisplayOverlay:)
													 name:kDisplayOverlay
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(startDisplayError:)
													 name:kDisplayError
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(stopDisplayError:)
													 name:kHideDisplayError
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(startDisplayOnlineState:)
													 name:kDisplayOnlineState
												   object:nil];
	}
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	// Clean window titlebar
	self.window.titleVisibility = NSWindowTitleHidden;
	self.window.titlebarAppearsTransparent = YES;
	self.window.styleMask |= NSFullSizeContentViewWindowMask;

	// Tracking the size of window after loaded
	[self trackWindowSize];

	// Error View
	[self initErrorView];
}

- (void)initErrorView {
	self.messageView = [SystemMessageView initFromXib];
	self.messageView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.contentView addSubview:self.messageView];

	[self.messageView addConstraint:[NSLayoutConstraint constraintWithItem:self.messageView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:270.0]];
	NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.messageView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:38.0];
	// Message View should be expandable depend on the length of text
	height.priority = NSLayoutPriorityDefaultLow;
	[self.messageView addConstraint:height];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.messageView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.messageView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];

	// Hidden by default
	self.messageView.hidden = YES;

	// Register
	[self.messageView registerToSystemMessage];
}

- (void)startDisplayLogin:(NSNotification *)notification
{
	[self displayLogin:notification.object];
}

- (void)displayLogin:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");
	if (cmd.open)
	{
		[self.contentView addSubview:self.loginViewController.view];
		[self.loginViewController.view setFrame:self.contentView.bounds];
		self.loginViewController.view.hidden = NO;

		[self.timeEntryListViewController.view removeFromSuperview];
		[self.overlayViewController.view removeFromSuperview];
	}
}

- (void)startDisplayTimeEntryList:(NSNotification *)notification
{
	[self displayTimeEntryList:notification.object];
}

- (void)displayTimeEntryList:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");
	if (cmd.open)
	{
		if ([self.loginViewController.view superview] != nil
			|| [self.timeEntryListViewController.view superview] == nil)
		{
			// Close error when loging in
			[self closeError];
			[self.loginViewController resetLoader];

			self.loginViewController.view.hidden = YES;
			[self.contentView addSubview:self.timeEntryListViewController.view];
			[self.timeEntryListViewController.view setFrame:self.contentView.bounds];

			[self.loginViewController.view removeFromSuperview];
			[self.overlayViewController.view removeFromSuperview];

			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kFocusTimer
																		object:nil];
		}
	}
}

- (void)startDisplayOverlay:(NSNotification *)notification
{
	[self displayOverlay:notification.object];
}

- (void)displayOverlay:(NSNumber *)type
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	// Setup overlay content

	[self.overlayViewController setType:[type intValue]];

	[self.contentView addSubview:self.overlayViewController.view];
	[self.overlayViewController.view setFrame:self.contentView.bounds];

	[self.loginViewController.view removeFromSuperview];
	[self.timeEntryListViewController.view removeFromSuperview];
}

- (void)startDisplayError:(NSNotification *)notification
{
	[self displayError:notification.object];
}

- (void)displayError:(NSString *)msg
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	NSString *errorMessage = msg == nil ? @"Error" : msg;
	[[SystemMessage shared] presentError:errorMessage subTitle:nil];

	// Reset loader if there is error
	// Have to check if login is present
	if (self.loginViewController.view.superview != nil)
	{
		[self.loginViewController resetLoader];
	}
}

- (void)startDisplayOnlineState:(NSNotification *)notification
{
	[self displayOnlineState:notification.object];
}

- (void)displayOnlineState:(NSNumber *)status
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	switch ([status intValue])
	{
		case 1 :
			[[SystemMessage shared] presentOffline:@"Error" subTitle:@"Offline, no network"];
			break;
		case 2 :
			[[SystemMessage shared] presentOffline:@"Error" subTitle:@"Offline, Toggl not responding"];
			break;
		default :
			[self closeError];
			break;
	}
}

- (void)stopDisplayError:(NSNotification *)notification
{
	[self closeError];
}

- (void)closeError
{
	self.messageView.hidden = YES;
}

- (void)keyUp:(NSEvent *)event
{
	if ([event keyCode] == kVK_DownArrow && ([event modifierFlags] & NSShiftKeyMask))
	{
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kFocusListing
																	object:nil];
	}
	else
	{
		[super keyUp:event];
	}
}

- (BOOL)isEditOpened
{
	return self.timeEntryListViewController.isEditorOpen;
}

- (void)trackWindowSize
{
	if (self.window == nil)
	{
		return;
	}
	[[TrackingService sharedInstance] trackWindowSize:self.window.frame.size];
}

- (void)setWindowMode:(WindowMode)mode
{
	switch (mode)
	{
		case WindowModeAlwaysOnTop :
			[self.window setLevel:NSFloatingWindowLevel];
			self.window.collectionBehavior = NSWindowCollectionBehaviorManaged;
			break;
		case WindowModeDefault :
			[self.window setLevel:NSNormalWindowLevel];
			break;
	}
}

@end