/*
 Project: DataBasin
 
 Copyright (C) 2010-2011 Free Software Foundation
 
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
#import "DBFieldCell.h"


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
  [super dealloc];
}

- (void)setSoapHandler:(DBSoap *)db
{
  dbs = db;
}

- (void)awakeFromNib
{
  NSRect scrollFrame;
  int i;
  

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
  NSString *statement;
  NSString *objId;
  int i;
  
  objId = [fieldObjId stringValue];
  objDevName = [dbs identifyObjectById: objId];
  NSLog(@"object is: %@", objDevName);

  sObj = [dbs describeSObject: objDevName];

  NSLog(@"object described.");
  NSLog(@"field names: %@", [sObj fieldNames]);
  arrayLabels = [[NSMutableArray arrayWithArray: [sObj fieldNames]] retain];
  arrayDevNames = [[NSMutableArray arrayWithArray: [sObj fieldNames]] retain];
  arrayValues = [[NSMutableArray arrayWithArray: [sObj fieldNames]] retain];
 
  [fieldTable reloadData];

}

/** --- Data Source --- **/


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [arrayDevNames count];
}
- (id) tableView: (NSTableView*)aTableView objectValueForTableColumn: (NSTableColumn*)column row: (int)rowIndex
{
  id retObj;

  retObj = nil;
  if ([[column identifier] isEqual: COLID_LABEL])
    retObj = [arrayLabels objectAtIndex: rowIndex];
  else if ([[column identifier] isEqual: COLID_DEVNAME])
    retObj = [arrayDevNames objectAtIndex: rowIndex];
  else if ([[column identifier] isEqual: COLID_VALUE])
    retObj = [arrayValues objectAtIndex: rowIndex];

  return retObj;
}

@end
