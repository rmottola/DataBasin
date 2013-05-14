/*
  Project: DataBasin

  Copyright (C) 2013 Free Software Foundation
  
  Author: Riccardo Mottola
  
  Created: 2013-05-14
  
  Preferences
  
  This application is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.
  
  This application is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.
  
  You should have received a copy of the GNU General Public
  License along with this library; if not, write to the Free
  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "DBLogger.h"
#import "Preferences.h"
#import "AppController.h"

#if defined(__APPLE__) && (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
#define NSUTF16StringEncoding 999
#endif

@implementation Preferences

- (id)init
{
  if ((self = [super init]))
    {
      [NSBundle loadNibNamed: @"Preferences" owner: self];
    }
  return self;
}

- (void)setAppController:(id)controller
{
  appController = controller;
}

- (void)awakeFromNib
{
  NSButtonCell *bCell;
  
#if defined(__APPLE__) && (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
  [popupStrEncoding setAutoenablesItems: NO];
  [[popupStrEncoding itemAtIndex: 1] setEnabled: NO];
#endif
  
  bCell = [[NSButtonCell alloc] init];
  buttonMatrix = [[NSMatrix alloc] initWithFrame:NSZeroRect mode:NSRadioModeMatrix prototype:bCell numberOfRows:1 numberOfColumns:2];
  [buttonMatrix setTarget: self];
  [buttonMatrix setAction:@selector(changePrefView:)];
  [buttonMatrix setAllowsEmptySelection:NO];
  [buttonMatrix setCellSize: NSMakeSize(80, 40)];
  [matrixScrollView setDocumentView:buttonMatrix];
  [bCell release];

  bCell = [buttonMatrix cellAtRow:0 column:0];
  [bCell setTitle:@"Application"];

  bCell = [buttonMatrix cellAtRow:0 column:1];
  [bCell setTitle:@"Connection"];

  [buttonMatrix sizeToCells];
  
}

- (IBAction)showPrefPanel:(id)sender
{
  NSUserDefaults *defaults;
  int index;

  defaults = [NSUserDefaults standardUserDefaults];
  
  index = 0;
  switch([[defaults valueForKey: @"StringEncoding"] intValue])
    {
      case NSUTF8StringEncoding:
        index = 0;
        break;
      case NSUTF16StringEncoding:
        index = 1;
        break;
      case NSISOLatin1StringEncoding:
        index = 2;
        break;
      case NSWindowsCP1252StringEncoding:
        index = 3;
        break;
    }
  [popupStrEncoding selectItemAtIndex: index];

  [buttPrefHttps setState: [[defaults valueForKey: @"UseHttps"] intValue]];

  index = 0;
  switch([[defaults valueForKey: @"LogLevel"] intValue])
    {
      case LogStandard:
        index = 0;
        break;
      case LogInformative:
        index = 1;
        break;
      case LogDebug:
        index = 2;
        break;
      default:
        NSLog(@"Unexpected log level");
        break;
    }
  [popupLogLevel selectItemAtIndex: index];

  [buttonMatrix selectCellAtRow:0 column:0];
  [buttonMatrix sendAction];
  [prefPanel makeKeyAndOrderFront:self];
}

- (IBAction)prefPanelCancel:(id)sender
{
  [prefPanel performClose: nil];
}

- (IBAction)prefPanelOk:(id)sender
{
  NSStringEncoding selectedEncoding;
  DBLogLevel selectedLogLevel;
  NSUserDefaults *defaults;

  defaults = [NSUserDefaults standardUserDefaults];
  
  selectedEncoding = NSUTF8StringEncoding;
  switch([popupStrEncoding indexOfSelectedItem])
    {
      case 0: selectedEncoding = NSUTF8StringEncoding;
        break;
      case 1: selectedEncoding = NSUTF16StringEncoding;
        break;
      case 2: selectedEncoding = NSISOLatin1StringEncoding;
        break;
      case 3: selectedEncoding = NSWindowsCP1252StringEncoding;
        break;
    }
    
  [defaults setObject:[NSNumber numberWithInt: selectedEncoding] forKey: @"StringEncoding"];

  [defaults setObject:[NSNumber numberWithInt: [buttPrefHttps state]] forKey: @"UseHttps"];

  selectedLogLevel = LogStandard;
  switch([popupLogLevel indexOfSelectedItem])
    {
      case 0: selectedLogLevel = LogStandard;
        break;
      case 1: selectedLogLevel = LogInformative;
        break;
      case 2: selectedLogLevel = LogDebug;
        break;
      default:
        break;
    }
  [defaults setObject:[NSNumber numberWithInt: selectedLogLevel] forKey: @"LogLevel"];

  [prefPanel performClose: nil];

  [appController reloadDefaults];
}

- (IBAction)changePrefView:(id)sender
{
  NSView *view;
  NSPoint origin;
  
  view = nil;
  origin = [viewPreferences frame].origin;

  if (sender == buttonMatrix)
    {
      int col;
    
      col = [sender selectedColumn];
      switch(col)
        {
          case 0: view = viewApplication;
            break;
          case 1: view = viewConnection;
            break;
        }
    }
  
  if (view)
    {
      NSView *superView;

      [view setFrameOrigin:origin];
      superView = [viewPreferences superview];
      [viewPreferences removeFromSuperview];
      [superView addSubview:view];
      viewPreferences = view;
    }
}

@end
