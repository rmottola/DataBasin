/* -*- mode: objc -*-
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

#import <AppKit/AppKit.h>

@class AppController;

@interface Preferences : NSObject
{
  AppController  *appController;
  
  IBOutlet NSPanel       *prefPanel;
  IBOutlet NSView        *viewPreferences;
  IBOutlet NSScrollView  *matrixScrollView;
  NSMatrix      *buttonMatrix;

  /* Application */
  IBOutlet NSView        *viewApplication;
  IBOutlet NSPopUpButton *popupStrEncoding;
  IBOutlet NSPopUpButton *popupLogLevel;

  /* Connection */
  IBOutlet NSView        *viewConnection;
  IBOutlet NSButton      *buttPrefHttps;
  IBOutlet NSTextField   *fieldUpBatchSize;

  /* CSV */
  IBOutlet NSView        *viewCSV;
  IBOutlet NSTextField   *fieldReadQualifier;
  IBOutlet NSTextField   *fieldReadSeparator;
  IBOutlet NSTextField   *fieldWriteQualifier;
  IBOutlet NSTextField   *fieldWriteSeparator;
}

- (void)setAppController:(id)controller;
- (IBAction)showPrefPanel:(id)sender;
- (IBAction)prefPanelCancel:(id)sender;
- (IBAction)prefPanelOk:(id)sender;
- (IBAction)changePrefView:(id)sender;

@end
