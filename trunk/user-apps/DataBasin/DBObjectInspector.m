/*
 Project: DataBasin
 
 Copyright (C) 2010-2014 Free Software Foundation
 
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


#import "DBObjectInspector.h"
#import <DataBasinKit/DBSObject.h>

#import "DBTextFormatter.h"

@implementation DBObjectInspector

- (id)init
{
  if ((self = [super init]))
    {
      winObjInspector = nil;
    }
  return self;
}

- (void)dealloc
{
  [arrayRows release];
  [super dealloc];
}

- (void)setSoapHandler:(DBSoap *)db
{
  dbs = db;
}

- (void)awakeFromNib
{
  NSTableColumn *col;
  NSCell *cell;
  DBTextFormatter *tf;
  
  tf = [[DBTextFormatter alloc] init];
  [tf setMaxLength:18];
  [fieldObjId setFormatter:tf];
  [tf release];

  col = [fieldTable tableColumnWithIdentifier:COLID_LABEL];
  cell = [col dataCell];
  [cell setSelectable:YES];
  [cell setEditable:NO];
  [col setDataCell:cell];
  
  col = [fieldTable tableColumnWithIdentifier:COLID_DEVNAME];
  cell = [col dataCell];
  [cell setSelectable:YES];
  [cell setEditable:NO];
  [col setDataCell:cell];
  
  col = [fieldTable tableColumnWithIdentifier:COLID_VALUE];
  cell = [col dataCell];
  [cell setSelectable:YES];
  [cell setEditable:NO];
  [col setDataCell:cell];
}

- (void)show
{
  if (winObjInspector == nil)
    [NSBundle loadNibNamed:@"ObjectInspector" owner:self];

  [winObjInspector makeKeyAndOrderFront:self];
}

- (IBAction)loadObject:(id)sender
{
  NSString *objDevName;
  NSMutableArray *arrayDevNames;
  
  NSString *objId;
  int i;
  
  objId = [fieldObjId stringValue];
  objDevName = [dbs identifyObjectById: objId];
  NSLog(@"[loadObject] object is: %@", objDevName);

  if (objDevName == nil)
    {
      NSLog(@"Invalid object.");
      [faultTextView setString:@"Invalid object ID or object not found"];
      [faultPanel makeKeyAndOrderFront:nil];
      return;
    }
  NSLog(@"dbs: %@, %@", [dbs class], dbs);
  sObj = [dbs describeSObject: objDevName];
  [sObj setValue: objId forField: @"Id"];
  [sObj setDBSoap: dbs];

  NS_DURING
    [sObj loadFieldValues];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
	[faultTextView setString:[localException reason]];
	[faultPanel makeKeyAndOrderFront:nil];
	return;
      }
  NS_ENDHANDLER

  NSLog(@"fields loaded...");
  [arrayRows release];
  arrayDevNames = [NSMutableArray arrayWithArray: [sObj fieldNames]];
  NSLog(@"field names are: %@", arrayDevNames);
  arrayRows = [[NSMutableArray arrayWithCapacity: [arrayDevNames count]] retain];

  for (i = 0; i < [arrayDevNames count]; i++)
    {
      NSString *fieldDevName;
      NSString *fieldLabel;
      NSString *fieldValue;
      NSDictionary *rowDict;


      fieldDevName = [arrayDevNames objectAtIndex: i];
      fieldLabel = [[sObj propertiesOfField: fieldDevName] objectForKey: @"label"];
      fieldValue =  [sObj valueForField: fieldDevName];
      
      rowDict = [NSDictionary dictionaryWithObjectsAndKeys: 
        fieldDevName, COLID_DEVNAME,
        fieldLabel, COLID_LABEL,
        fieldValue, COLID_VALUE,
        NULL];
      [arrayRows addObject: rowDict];
    }
 
  [fieldTable reloadData];

  [winObjInspector setTitle: objDevName];

}

/** --- Data Source --- **/


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [arrayRows count];
}

- (id) tableView: (NSTableView*)aTableView objectValueForTableColumn: (NSTableColumn*)column row: (NSInteger)rowIndex
{
  id retObj;
  NSDictionary *row;
  
  row = [arrayRows objectAtIndex: rowIndex];
  retObj = [row objectForKey: [column identifier]];
  return retObj;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
  [arrayRows sortUsingDescriptors: [tableView sortDescriptors]];
  [fieldTable reloadData];
}

@end
