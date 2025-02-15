/*
  Project: DataBasin

  Copyright (C) 2013-2020 Free Software Foundation
  
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
  
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "DBLogger.h"
#import "Preferences.h"
#import "AppController.h"

#import <DataBasinKit/DBCSVWriter.h>

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
#if defined(__APPLE__)
  [bCell setBezelStyle:NSShadowlessSquareBezelStyle];
#endif
  buttonMatrix = [[NSMatrix alloc] initWithFrame:NSZeroRect mode:NSRadioModeMatrix prototype:bCell numberOfRows:1 numberOfColumns:3];
  [buttonMatrix setTarget: self];
  [buttonMatrix setAction:@selector(changePrefView:)];
  [buttonMatrix setAllowsEmptySelection:NO];
  [buttonMatrix setCellSize: NSMakeSize(85, 40)];
  [matrixScrollView setDocumentView:buttonMatrix];
  [bCell release];

  bCell = [buttonMatrix cellAtRow:0 column:0];
  [bCell setTitle:@"Application"];
  [bCell setTag: 0];

  bCell = [buttonMatrix cellAtRow:0 column:1];
  [bCell setTitle:@"Connection"];
  [bCell setTag: 1];

  bCell = [buttonMatrix cellAtRow:0 column:2];
  [bCell setTitle:@"CSV"];
  [bCell setTag: 2];

  [buttonMatrix sizeToCells];
  
}

- (IBAction)showPrefPanel:(id)sender
{
  NSUserDefaults *defaults;
  int index;
  id value;
  int i;
  BOOL b;
  defaults = [NSUserDefaults standardUserDefaults];

  if ([defaults boolForKey:@"FilterObjects_Share"])
    [checkFilterShare setState:NSOnState];
  else
    [checkFilterShare setState:NSOffState];

  if ([defaults boolForKey:@"FilterObjects_History"])
    [checkFilterHistory setState:NSOnState];
  else
    [checkFilterHistory setState:NSOffState];

  if ([defaults boolForKey:@"FilterObjects_ChangeEvent"])
    [checkFilterChangeEvent setState:NSOnState];
  else
    [checkFilterChangeEvent setState:NSOffState];

  if ([defaults boolForKey:@"FilterObjects_Feed"])
    [checkFilterFeed setState:NSOnState];
  else
    [checkFilterFeed setState:NSOffState];
    
  index = 0;
  switch([defaults integerForKey: @"StringEncoding"])
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

  index = 0;
  switch([defaults integerForKey: @"LogLevel"])
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

  
  if ([defaults boolForKey:@"DescribeFieldTypesInQueries"])
    [checkCheckFieldTypes setState:NSOnState];
  else
    [checkCheckFieldTypes setState:NSOffState];

    
  i = [defaults integerForKey:@"UpBatchSize"];
  if (i > 0)
    [fieldUpBatchSize setIntValue:i];

  i = [defaults integerForKey:@"DownBatchSize"];
  if (i > 0)
    [fieldDownBatchSize setIntValue:i];

  i = [defaults integerForKey:@"MaxSOQLQueryLength"];
  if (i > 0)
    [fieldMaxSOQLLength setIntValue:i];    
  
  b = [defaults boolForKey:@"RunAssignmentRules"];
  [checkAssignmentRules setIntValue:b];

  value = [defaults stringForKey:@"CSVReadQualifier"];
  if (value)
    [fieldReadQualifier setStringValue:value];
  value = [defaults stringForKey:@"CSVReadSeparator"];
  if (value)
    [fieldReadSeparator setStringValue:value];
  value = [defaults stringForKey:@"CSVWriteQualifier"];
  if (value)
    [fieldWriteQualifier setStringValue:value];
  value = [defaults stringForKey:@"CSVWriteSeparator"];
  if (value)
    [fieldWriteSeparator setStringValue:value];

  
  i = [defaults integerForKey:CSVWriteLineBreakHandling];
  switch (i)
    {
    case DBCSVLineBreakDelete:
      [matrixWriteLineBreak selectCellAtRow:1  column:0];
      break;
    case DBCSVLineBreakReplaceWithSpace:
      [matrixWriteLineBreak selectCellAtRow:2  column:0];
      break;
    case DBCSVLineBreakNoChange:
    default: /* default treated as DBCSVLineBreakNoChange */
      [matrixWriteLineBreak selectCellAtRow:0  column:0];
    }

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
  int upBatchSize;
  int downBatchSize;
  int maxSOQLLen;
  BOOL runAssignmentRules;
  NSString *s;

  defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool:[checkFilterShare state]  forKey:@"FilterObjects_Share"];
  [defaults setBool:[checkFilterHistory state]  forKey:@"FilterObjects_History"];
  [defaults setBool:[checkFilterChangeEvent state]  forKey:@"FilterObjects_ChangeEvent"];
  [defaults setBool:[checkFilterFeed state]  forKey:@"FilterObjects_Feed"];
  [defaults setBool:[checkCheckFieldTypes state]  forKey:@"DescribeFieldTypesInQueries"];
  
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

  upBatchSize = [fieldUpBatchSize intValue];
  if (upBatchSize > 0)
    {
      if (upBatchSize > MAX_BATCH_SIZE)
        upBatchSize = MAX_BATCH_SIZE;
      [defaults setObject:[NSNumber numberWithInt:upBatchSize] forKey:@"UpBatchSize"];
    }
  
  downBatchSize = [fieldDownBatchSize intValue];
  if (downBatchSize > 0)
    [defaults setObject:[NSNumber numberWithInt:downBatchSize] forKey:@"DownBatchSize"];
  
  maxSOQLLen = [fieldMaxSOQLLength intValue];
  if (maxSOQLLen > 0)
    {
      if (maxSOQLLen > MAX_SOQL_LENGTH)
        maxSOQLLen = MAX_SOQL_LENGTH;
      [defaults setObject:[NSNumber numberWithInt: maxSOQLLen] forKey:@"MaxSOQLQueryLength"];
    }
  
  runAssignmentRules = [checkAssignmentRules intValue];
  [defaults setBool:runAssignmentRules forKey:@"RunAssignmentRules"];

  s = [fieldReadQualifier stringValue];
  if (s && [s length] == 1)
    {
      [defaults setObject:s forKey:@"CSVReadQualifier"];
    }
  else
    {
      // FIXME should return warning
      return;
    }

  s = [fieldReadSeparator stringValue];
  if (s && [s length] == 1)
    {
      [defaults setObject:s forKey:@"CSVReadSeparator"];
    }
  else
    {
      // FIXME should return warning
      return;
    }

  s = [fieldWriteQualifier stringValue];
  if (s && [s length] == 1)
    {
      [defaults setObject:s forKey:@"CSVWriteQualifier"];
    }
  else
    {
      // FIXME should return warning
      return;
    }

  s = [fieldWriteSeparator stringValue];
  if (s && [s length] == 1)
    {
      [defaults setObject:s forKey:@"CSVWriteSeparator"];
    }
  else
    {
      // FIXME should return warning
      return;
    }

  switch ([matrixWriteLineBreak selectedRow])
    {
    case -1:
      NSLog(@"unselected value in matrixWriteLineBreak selection");
      break;
    case 0:
      [defaults setObject:[NSNumber numberWithInt:DBCSVLineBreakNoChange] forKey:CSVWriteLineBreakHandling];
      break;
    case 1:
        [defaults setObject:[NSNumber numberWithInt:DBCSVLineBreakDelete] forKey:CSVWriteLineBreakHandling];
      break;
    case 2:
      [defaults setObject:[NSNumber numberWithInt:DBCSVLineBreakReplaceWithSpace] forKey:CSVWriteLineBreakHandling];
      break;
    default:
      NSLog(@"unexpected value in matrixWriteLineBreak selection");
    }

  [prefPanel performClose: nil];

  [appController reloadDefaults];
}

- (IBAction)changePrefView:(id)sender
{
  NSView *view;
  
  view = nil;
  

  if (sender == buttonMatrix)
    {
      NSInteger tag;

      tag = [[sender selectedCell] tag];
      switch(tag)
        {
          case 0: view = viewApplication;
            break;
          case 1: view = viewConnection;
            break;
          case 2: view = viewCSV;
            break;
        }
    }
  
  if (view)
    {
      NSView *superView;
      NSPoint origin;
 
      origin = [viewPreferences frame].origin;
      [view setFrameOrigin:origin];
      superView = [viewPreferences superview];
      [viewPreferences retain];
      [viewPreferences removeFromSuperview];
      [superView addSubview:view];
      viewPreferences = view;
    }
}

@end
