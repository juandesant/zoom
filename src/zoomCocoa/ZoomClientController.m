//
//  ZoomClientController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Incorporates changes contributed by Collin Pieper

#import "ZoomClientController.h"
#import "ZoomPreferenceWindow.h"
#import "ZoomGameInfoController.h"
#import "ZoomStoryOrganiser.h"
#import "ZoomSkeinController.h"

#import "ZoomAppDelegate.h"

@implementation ZoomClientController

- (id) init {
    self = [super initWithWindowNibName: @"ZoomClient"];

    if (self) {
        [self setShouldCloseDocument: YES];
		isFullscreen = NO;
		finished = NO;
    }

    return self;
}

- (void) dealloc {
    if (zoomView) [zoomView setDelegate: nil];
    if (zoomView) [zoomView killTask];
    
    [super dealloc];
}

- (void) windowDidLoad {
	if ([[self document] defaultView] != nil) {
		// Replace the view
		NSRect viewFrame = [zoomView frame];
		NSView* superview = [zoomView superview];
		
		[zoomView removeFromSuperview];
		//[zoomView release];
		zoomView = [[[self document] defaultView] retain];
		
		[superview addSubview: zoomView];
		[zoomView setFrame: viewFrame];
		[zoomView setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
	}
	
	[self setWindowFrameAutosaveName: @"ZoomClientWindow"];

	[[self window] setAlphaValue: 0.99];
//	[[self window] invalidateShadow];
    
	[zoomView setDelegate: self];
    [zoomView runNewServer: nil];
	
	// Add a skein view as an output receiver for the ZoomView
	[zoomView addOutputReceiver: [[self document] skein]];
}

- (IBAction) restartZMachine: (id) sender {
	[zoomView runNewServer: nil];
}

- (void) zMachineStarted: (id) sender {
    [[zoomView zMachine] loadStoryFile: [[self document] gameData]];
	
	if ([[self document] autosaveData] != nil) {
		NSUnarchiver* decoder;
		
		decoder = [[NSUnarchiver alloc] initForReadingWithData: [[self document] autosaveData]];
		
		[zoomView restoreAutosaveFromCoder: decoder];
		
		[decoder release];
		[[self document] setAutosaveData: nil];
	}
	
	if ([[self document] defaultView] != nil && [[self document] saveData] != nil) {
		// Restore the save data
		[[[self document] defaultView] restoreSaveState: [[self document] saveData]];
	}
}

- (void) zMachineFinished: (id) sender {
	[[self window] setTitle: [NSString stringWithFormat: @"%@ (finished)", [[self window] title]]];
	finished = YES;
	
	if (isFullscreen) [self playInFullScreen: self];
}

- (void) zoomViewIsNotResizable {
	//[[self window] setContentMaxSize: [zoomView frame].size];
	[[self window] setContentMinSize: [zoomView frame].size];
	//[[self window] setShowsResizeIndicator: NO];
}

- (BOOL) useSavePackage {
	// Using a save package allows us to restore games without needing to restart them first
	// It also allows us to show a preview in the iFiction window
	return YES;
}

- (NSString*) defaultSaveDirectory {
	ZoomPreferences* prefs = [ZoomPreferences globalPreferences];
	
	if ([prefs keepGamesOrganised]) {
		// Get the directory for this game
		NSString* gameDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: [[self document] storyId]
																				  create: YES];
		NSString* saveDir = [gameDir stringByAppendingPathComponent: @"Saves"];
		
		BOOL isDir = NO;
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: saveDir
												  isDirectory: &isDir]) {
			if (![[NSFileManager defaultManager] createDirectoryAtPath: saveDir
															attributes: nil]) {
				// Couldn't create the directory
				return nil;
			}
			
			isDir = YES;
		} else {
			if (!isDir) {
				// Some inconsiderate person stuck a file here
				return nil;
			}
		}
		
		return saveDir;
	}
	
	return nil;
}

- (void) showGamePreferences: (id) sender {
	ZoomPreferenceWindow* gamePrefs;
	
	gamePrefs = [[ZoomPreferenceWindow alloc] init];
	
	[NSApp beginSheet: [gamePrefs window]
	   modalForWindow: [self window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
    [NSApp runModalForWindow: [gamePrefs window]];
    [NSApp endSheet: [gamePrefs window]];
	
	[[gamePrefs window] orderOut: self];
	[gamePrefs release];
}

// = Setting up the game info window =

- (IBAction) recordGameInfo: (id) sender {
	ZoomGameInfoController* sgI = [ZoomGameInfoController sharedGameInfoController];
	ZoomStory* storyInfo = [[self document] storyInfo];

	if ([sgI gameInfo] == storyInfo) {
		// Grr, annoying bug discovered here.
		// Previously we called [sgI title], etc directly here.
		// But, there was a case where the iFiction window could have become reactivated before this
		// call (didn't always happen, it seems, which is why I missed it). In this case, after the
		// title was set, the iFiction window would be notified that a change to the story settings
		// had occured, and update itself, AND THE GAMEINFO WINDOW, accordingly. Which replaced all
		// the rest of the settings with the settings of the currently selected game. DOH!
		NSDictionary* sgIValues = [sgI dictionary];
		
		[storyInfo setTitle: [sgIValues objectForKey: @"title"]];
		[storyInfo setHeadline: [sgIValues objectForKey: @"headline"]];
		[storyInfo setAuthor: [sgIValues objectForKey: @"author"]];
		[storyInfo setGenre: [sgIValues objectForKey: @"genre"]];
		[storyInfo setYear: [[sgIValues objectForKey: @"year"] intValue]];
		[storyInfo setGroup: [sgIValues objectForKey: @"group"]];
		[storyInfo setComment: [sgIValues objectForKey: @"comments"]];
		[storyInfo setTeaser: [sgIValues objectForKey: @"teaser"]];
		[storyInfo setZarfian: [[sgIValues objectForKey: @"zarfRating"] unsignedIntValue]];
		[storyInfo setRating: [[sgIValues objectForKey: @"rating"] floatValue]];
		
		[[[NSApp delegate] userMetadata] writeToDefaultFile];
	}
}

- (IBAction) updateGameInfo: (id) sender {
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [[self document] storyInfo]];
}

- (void)windowDidResignMain:(NSNotification *)aNotification {
	if (isFullscreen) {
		[self playInFullScreen: self];
	}
	
	[self recordGameInfo: self];
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];

	if ([[ZoomSkeinController sharedSkeinController] skein] == [[self document] skein]) {
		[[ZoomSkeinController sharedSkeinController] setSkein: nil];
	}
}

- (BOOL) windowShouldClose: (id) sender {	
	// Record any game information
	[self recordGameInfo: self];
	
	// Record autosave data
	NSMutableData* autosaveData = [[NSMutableData alloc] init];
	NSArchiver* theCoder = [[NSArchiver alloc] initForWritingWithMutableData: autosaveData];
	
	BOOL autosave = [[ZoomPreferences globalPreferences] autosaveGames]?[zoomView createAutosaveDataWithCoder: theCoder]:NO;
	
	[theCoder release];
	
	NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: [[self document] storyId]
																				  create: autosave];
	NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];
	
	if (autosave) {
		// Produce an autosave file
		[autosaveData writeToFile: autosaveFile atomically: YES];
	} else {
		if ([[NSFileManager defaultManager] fileExistsAtPath: autosaveFile]) {
			[[NSFileManager defaultManager] removeFileAtPath: autosaveFile
													 handler: nil];
		}
	}
	
	[autosaveData release];
	
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification {
	// Can't do stuff here: [self document] has been set to nil
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [[self document] storyInfo]];
	[[ZoomSkeinController sharedSkeinController] setSkein: [[self document] skein]];
}

// = GameInfo updates =

- (IBAction) infoNameChanged: (id) sender {
	[[[self document] storyInfo] setTitle: [[ZoomGameInfoController sharedGameInfoController] title]];
}

- (IBAction) infoHeadlineChanged: (id) sender {
	[[[self document] storyInfo] setHeadline: [[ZoomGameInfoController sharedGameInfoController] headline]];
}

- (IBAction) infoAuthorChanged: (id) sender {
	[[[self document] storyInfo] setAuthor: [[ZoomGameInfoController sharedGameInfoController] author]];
}

- (IBAction) infoGenreChanged: (id) sender {
	[[[self document] storyInfo] setGenre: [[ZoomGameInfoController sharedGameInfoController] genre]];
}

- (IBAction) infoYearChanged: (id) sender {
	[[[self document] storyInfo] setYear: [[ZoomGameInfoController sharedGameInfoController] year]];
}

- (IBAction) infoGroupChanged: (id) sender {
	[[[self document] storyInfo] setGroup: [[ZoomGameInfoController sharedGameInfoController] group]];
}

- (IBAction) infoCommentsChanged: (id) sender {
	[[[self document] storyInfo] setComment: [[ZoomGameInfoController sharedGameInfoController] comments]];
}

- (IBAction) infoTeaserChanged: (id) sender {
	[[[self document] storyInfo] setTeaser: [[ZoomGameInfoController sharedGameInfoController] teaser]];
}

- (IBAction) infoZarfRatingChanged: (id) sender {
	[[[self document] storyInfo] setZarfian: [[ZoomGameInfoController sharedGameInfoController] zarfRating]];
}

- (IBAction) infoMyRatingChanged: (id) sender {
	[[[self document] storyInfo] setRating: [[ZoomGameInfoController sharedGameInfoController] rating]];
}

// = Various IB actions =

- (IBAction) playInFullScreen: (id) sender {
	if (isFullscreen) {
		// Show the menubar
		[NSMenu setMenuBarVisible: YES];

		// Stop being fullscreen
		[zoomView retain];
		[zoomView removeFromSuperview];
		
		[[self window] setFrame: oldWindowFrame
						display: YES
						animate: YES];
		[[self window] setShowsResizeIndicator: YES];
		
		[zoomView setScaleFactor: 1.0];
		[zoomView setFrame: [[[self window] contentView] bounds]];
		[[[self window] contentView] addSubview: zoomView];
		[zoomView release];
		
		isFullscreen = NO;
	} else {
		// Start being fullscreen
		[[self window] makeKeyAndOrderFront: self];
		oldWindowFrame = [[self window] frame];
		
		// Finish off zoomView
		NSSize oldZoomViewSize = [zoomView frame].size;
		
		[zoomView retain];
		[zoomView removeFromSuperviewWithoutNeedingDisplay];
		
		// Resize the window
		NSRect frame = [[[self window] screen] frame];
		[[self window] setShowsResizeIndicator: NO];
		frame = [NSWindow frameRectForContentRect: frame
										styleMask: [[self window] styleMask]];
		[[self window] setFrame: frame
						display: YES
						animate: YES];
		
		// Hide the menubar
		[NSMenu setMenuBarVisible: NO];
		
		// Resize, reposition the zoomView
		NSRect newZoomViewFrame = [[[self window] contentView] bounds];
		NSRect newZoomViewBounds;
		
		newZoomViewBounds.origin = NSMakePoint(0,0);
		newZoomViewBounds.size   = newZoomViewFrame.size;
		
		double ratio = oldZoomViewSize.width/newZoomViewFrame.size.width;
		[zoomView setFrame: newZoomViewFrame];
		[zoomView setScaleFactor: ratio];
		
		// Add it back in again
		[[[self window] contentView] addSubview: zoomView];
		[zoomView release];
		
		isFullscreen = YES;
	}
}

// = Window title =
- (NSString *) windowTitleForDocumentDisplayName: (NSString *)displayName {
	ZoomStory* story = [[self document] storyInfo];
	
	if (story == nil) return displayName;
	
	if (finished) {
		return [NSString stringWithFormat: @"%@ (finished)", [story title]];
	}
	
	return [story title];
}

- (ZoomView*) zoomView {
	return zoomView;
}

@end
