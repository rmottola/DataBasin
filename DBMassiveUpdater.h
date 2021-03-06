/*
 Project: DataBasin
 
 Copyright (C) 2010-2019 Free Software Foundation
 
 Author: Riccardo Mottola
 
 Created: 2010-12-15
 
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


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <DataBasinKit/DBSoap.h>

#define COLID_LABEL    @"Label"
#define COLID_DEVNAME  @"DevName"
#define COLID_VALUE    @"Value"

@interface DBMassiveUpdater : NSObject
{
  DBSoap *dbs; /* soap handler */

  IBOutlet NSTextField *fieldObjId;
  IBOutlet NSWindow *winMassiveUpdater;
  IBOutlet NSTableView *fieldTable;
  IBOutlet NSTextView *faultTextView;
  IBOutlet NSPanel *faultPanel;
  IBOutlet NSButton *fileBrowseButton;
  IBOutlet NSButton *loadButton;
  IBOutlet NSButton *updateButton;
  IBOutlet NSSearchField *searchField;
  IBOutlet NSTextField *statusField;
  IBOutlet NSProgressIndicator *progIndicator;

  /* data source objects */
  DBSObject      *sObj;
  NSMutableArray *arrayRows;
  NSMutableArray *filteredRows;

  NSMutableArray *updatedRows;
}

/** sets the Soap handler class, which needs to remain valid througout the inspector existence */
- (void)setSoapHandler:(DBSoap *)db;
- (void)show;
- (IBAction)search:(id)sender;
- (IBAction)loadObject:(id)sender;
- (IBAction)updateObject:(id)sender;

@end
