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
      arrayRows = nil;
      updatedRows = nil;
      filteredRows = nil;
      sObj = nil;
    }
  return self;
}

- (void)dealloc
{
  if (sObj)
    [sObj release];
  [arrayRows release];
  [filteredRows release];
  [updatedRows release];
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
  [cell setEditable:YES];
  [col setDataCell:cell];
  
  [updateButton setEnabled:NO];
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
  NSInteger i;
  
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
  if(sObj)
    [sObj release];
  sObj = [dbs describeSObject: objDevName];
  [sObj retain];
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

  if (arrayRows)
    [arrayRows release];
  arrayDevNames = [NSMutableArray arrayWithArray: [sObj fieldNames]];
  arrayRows = [[NSMutableArray arrayWithCapacity: [arrayDevNames count]] retain];

  if (updatedRows)
    [updatedRows release];
  updatedRows = [[NSMutableArray arrayWithCapacity: 1] retain];

  if (filteredRows)
    [filteredRows removeAllObjects];
  else
    filteredRows = [[NSMutableArray alloc] init];

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
      [filteredRows addObject:[NSNumber numberWithInt:i]];
    }
 
  [fieldTable reloadData];

  [winObjInspector setTitle: objDevName];
  [updateButton setState:NSOffState];
}

- (IBAction)updateObject:(id)sender
{
  NSUInteger i;
  NSMutableArray *fieldNames;

  if (!updatedRows || [updatedRows count] == 0)
    return;
  
  fieldNames = [[NSMutableArray alloc] initWithCapacity:1];
  for (i = 0; i < [updatedRows count]; i++)
    {
      NSDictionary *fieldDict;
      NSString *fieldName;
      NSString *fieldValue;

      fieldDict = [updatedRows objectAtIndex:i];
      fieldName = [fieldDict objectForKey:COLID_DEVNAME];
      fieldValue = [fieldDict objectForKey:COLID_VALUE];
      [sObj setValue:fieldValue forField:fieldName];
      [fieldNames addObject:fieldName];
    }

  NS_DURING
    [sObj storeValuesForFields: fieldNames];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
        [fieldNames release];
        return;
      }
  NS_ENDHANDLER
  
  [fieldNames release];
  [updateButton setEnabled:NO];
  [updatedRows removeAllObjects];
  [fieldTable setNeedsDisplay:YES];
}

 - (IBAction)search:(id)sender
{
  NSString *searchStr;
  NSUInteger i;

  searchStr = [searchField stringValue];
  NSLog(@"search string: %@", searchStr);
  [filteredRows removeAllObjects];
  if (searchStr && [searchStr length])
    {
      for (i = 0; i < [arrayRows count]; i++)
        {
          BOOL include;
          NSDictionary *row;

          row = [arrayRows objectAtIndex:i];
          include = NO;
          include |= [[row objectForKey:COLID_DEVNAME] rangeOfString:searchStr].location != NSNotFound;
          if (include)
            [filteredRows addObject:[NSNumber numberWithInt:i]];
        }
    }
  else
    {
      for (i = 0; i < [arrayRows count]; i++)
        [filteredRows addObject:[NSNumber numberWithInt:i]];
    }
  NSLog(@"filteredRows: %@", filteredRows);
  [fieldTable reloadData];
}


/** --- Data Source --- **/


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [filteredRows count];
}

- (id) tableView: (NSTableView*)aTableView objectValueForTableColumn: (NSTableColumn*)column row: (NSInteger)rowIndex
{
  id retObj;
  NSDictionary *row;
  NSUInteger originalRowIndex;

  originalRowIndex = [[filteredRows objectAtIndex:rowIndex] intValue];
  row = [arrayRows objectAtIndex: originalRowIndex];
  retObj = [row objectForKey: [column identifier]];
  return retObj;
}

- (BOOL) tableView:(NSTableView *)aTableView shouldEditTableColumn: (NSTableColumn *)column row: (NSInteger)rowIndex
{
  NSUInteger originalRowIndex;

  originalRowIndex = [[filteredRows objectAtIndex:rowIndex] intValue];
  /* we we always return editable for column/row,
    however we selectively set the cell as selectable and editable/non editable */
  if ([[column identifier] isEqualTo:COLID_VALUE])
    {
      NSDictionary *originalRowDict;

      NSString *fieldName;
      NSDictionary *fieldProps;
      BOOL updateable;
      NSCell *cell;
      
      originalRowDict = [arrayRows objectAtIndex: originalRowIndex];
      fieldName = [originalRowDict objectForKey:COLID_DEVNAME];
      fieldProps = [sObj propertiesOfField:fieldName];
      updateable = NO;
      if ([[fieldProps objectForKey:@"updateable"] isEqualToString:@"true"])
        updateable = YES;
      
      cell = [column dataCell];
      [cell setSelectable:YES];
      [cell setEditable:updateable];
      [column setDataCell:cell];
    }
  
  /* we do not block editing here, or selecting a cell fails too */
  return YES;
}

- (void) tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aCol row:(NSInteger)rowIndex
{
  NSDictionary *originalRowDict;
  NSDictionary *newRowDict;
  NSString *fieldName;
  NSDictionary *fieldProps;
  BOOL updateable;
  NSUInteger originalRowIndex;

  originalRowIndex = [[filteredRows objectAtIndex:rowIndex] intValue];  
  updateable = NO;
  
  /* Only editing of the value of a field is supported */
  if (![[aCol identifier] isEqualTo:COLID_VALUE])
    return;

  originalRowDict = [arrayRows objectAtIndex: originalRowIndex];
  fieldName = [originalRowDict objectForKey:COLID_DEVNAME];
  fieldProps = [sObj propertiesOfField:fieldName];
  updateable = NO;
  if ([[fieldProps objectForKey:@"updateable"] isEqualToString:@"true"])
    updateable = YES;

  if (!updateable)
    return;

  /* if we didn't change anything, don't do anything */
  if ([[originalRowDict objectForKey:COLID_VALUE] isEqualTo:anObject])
    return;
  
  newRowDict = [NSDictionary dictionaryWithObjectsAndKeys: 
                            [originalRowDict objectForKey:COLID_DEVNAME], COLID_DEVNAME,                            [originalRowDict objectForKey:COLID_LABEL], COLID_LABEL,
                             anObject, COLID_VALUE,
                             NULL];

  [arrayRows replaceObjectAtIndex:originalRowIndex withObject:newRowDict];
  [updatedRows addObject:newRowDict];
  
  if ([updatedRows count] > 0)
    [updateButton setEnabled:YES];
}

/* We override this method to visually show properties of cells.
   - if the field is updateable
   - if the field contains values to update
*/
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)rowIndex
{
  NSDictionary *originalRowDict;
  NSString *fieldName;
  NSDictionary *fieldProps;
  BOOL updateable;
  BOOL updated;
  NSFont *font;
  NSFontManager *fm;
  NSUInteger i;
  

  updateable = NO;
  font = [(NSCell *)cell font];
  fm = [NSFontManager sharedFontManager];
  
  originalRowDict = [arrayRows objectAtIndex: rowIndex];
  fieldName = [originalRowDict objectForKey:COLID_DEVNAME];
  fieldProps = [sObj propertiesOfField:fieldName];
  updateable = NO;
  if ([[fieldProps objectForKey:@"updateable"] isEqualToString:@"true"])
    updateable = YES;

  /* now we look if the field is among the one being updated */
  updated = NO;
  i = 0;
  while (i < [updatedRows count] && !updated)
    {
      if ([[[updatedRows objectAtIndex:i] objectForKey:COLID_DEVNAME] isEqualToString:fieldName])
        {
          updated = YES;
        }
      i++;
    }
  
  /* depeding if the row has updated values or not, we set properties */
  if (updated && [[column identifier] isEqualTo:COLID_VALUE])
    [cell setTextColor:[NSColor blueColor]];
  else
    [cell setTextColor:[NSColor blackColor]];

  if (!updateable && [[column identifier] isEqualTo:COLID_VALUE])
    [cell setFont:[fm convertFont:font toHaveTrait:NSItalicFontMask]];
  else
    [cell setFont:[fm convertFont:font toNotHaveTrait:NSItalicFontMask]];

}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
  [arrayRows sortUsingDescriptors: [tableView sortDescriptors]];
  [fieldTable reloadData];
}

@end

