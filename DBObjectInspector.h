/*
 Project: DataBasin
 
 Copyright (C) 2010-2016 Free Software Foundation
 
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
 
 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free
 Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <DataBasinKit/DBSoap.h>

#define COLID_LABEL    @"Label"
#define COLID_DEVNAME  @"DevName"
#define COLID_VALUE    @"Value"

@interface DBObjectInspector : NSObject
{
  DBSoap *dbs; /* soap handler */

  IBOutlet NSTextField *fieldObjId;
  IBOutlet NSWindow *winObjInspector;
  IBOutlet NSTableView *fieldTable;
  IBOutlet NSTextView *faultTextView;
  IBOutlet NSPanel *faultPanel;
  IBOutlet NSButton *loadButton;
  IBOutlet NSButton *updateButton;
  IBOutlet NSSearchField *searchField;
  IBOutlet NSTextField *statusField;

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
