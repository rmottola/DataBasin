/*
 Project: DataBasin
 
 Copyright (C) 2010-2023 Free Software Foundation
 
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


#import "DBObjectInspector.h"
#import <DataBasinKit/DBSObject.h>
#import <DataBasinKit/DBSFTypeWrappers.h>
#import "DBTextFormatter.h"

NSString * const DBOIStatusKey = @"Status";

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
  NSMenu *searchRecentMenu;
  NSMenuItem <NSMenuItem> *menuItem;
  
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
  
  /* set up Search Field and its menu */
  [searchField  setRecentsAutosaveName:@"ObjectInspectorSearchRecents"];
  searchRecentMenu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
  
  menuItem = [[NSMenuItem alloc] initWithTitle:@"Clear"
                                        action:NULL keyEquivalent:@""];
  [menuItem setTag:NSSearchFieldClearRecentsMenuItemTag];
  [searchRecentMenu insertItem:menuItem atIndex:0];
  
  menuItem = [NSMenuItem separatorItem];
  [menuItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
  [searchRecentMenu insertItem:menuItem atIndex:1];
  
  menuItem = [[NSMenuItem alloc] initWithTitle:@"Recent Searches"
                                        action:NULL keyEquivalent:@""];
  [menuItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
  [searchRecentMenu insertItem:menuItem atIndex:2];
  
  
  menuItem = [[NSMenuItem alloc] initWithTitle:@"Recents"
                                        action:NULL keyEquivalent:@""];
  [menuItem setTag:NSSearchFieldRecentsMenuItemTag];
  [searchRecentMenu insertItem:menuItem atIndex:3];
  
  [[searchField cell] setSearchMenuTemplate:searchRecentMenu];

  [searchRecentMenu release];

  /* now set the first responder */
  [winObjInspector makeFirstResponder:fieldObjId];
}

- (void)show
{
  if (winObjInspector == nil)
    [NSBundle loadNibNamed:@"ObjectInspector" owner:self];

  [winObjInspector makeKeyAndOrderFront:self];
}

- (void)resetUI:(NSDictionary *)statusDict
{
  NSString *statusMsg;

  statusMsg = [statusDict objectForKey:DBOIStatusKey];
  if (statusMsg)
    {
      [statusField setStringValue:statusMsg];
      if ([statusMsg isEqualToString:@"Update Error"])
        {
          [loadButton setEnabled:YES];
          [updateButton setEnabled:YES];
          return;
        }
    }
  [loadButton setEnabled:YES];
  [updateButton setEnabled:NO];
  [searchField setStringValue:@""];
}

- (void)performLoadObject:(id)argObj
{
  NSString *objDevName;
  NSMutableArray *arrayDevNames;
  NSAutoreleasePool *arp;
  
  NSString *objId;
  NSInteger i;
  
  arp = [NSAutoreleasePool new];
  
  objId = [fieldObjId stringValue];
  objDevName = [dbs identifyObjectById: objId];
  NSLog(@"[loadObject] object is: %@", objDevName);

  if (objDevName == nil)
    {
      NSLog(@"Invalid object.");
      [faultTextView setString:@"Invalid object ID or object not found"];
      [faultPanel performSelectorOnMainThread:@selector(makeKeyAndOrderFront:) withObject:nil waitUntilDone:NO];
      [self resetUI:[NSDictionary dictionaryWithObjectsAndKeys:@"Invalid object", DBOIStatusKey, nil]];
      [arp release];
      return;
    }

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
        [faultPanel performSelectorOnMainThread:@selector(makeKeyAndOrderFront:) withObject:nil waitUntilDone:NO];
        [self resetUI:[NSDictionary dictionaryWithObjectsAndKeys:@"Exception", DBOIStatusKey, nil]];
        [arp release];
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
      id       fieldValueObj;
      NSString *fieldValueStr;
      NSDictionary *rowDict;

      /* We get object values.
         Not all values are Strings.
         Addresses are complex objects, for example */
      
      fieldDevName = [arrayDevNames objectAtIndex: i];
      fieldLabel = [[sObj propertiesOfField: fieldDevName] objectForKey: @"label"];
      fieldValueObj =  [sObj valueForField: fieldDevName];
      if ([fieldValueObj isKindOfClass:[NSString class]])
        {
          fieldValueStr = (NSString *)fieldValueObj;
        }
      else if ([fieldValueObj isKindOfClass:[NSDictionary class]])
        {
          NSArray *coderOrder;

          coderOrder = [fieldValueObj objectForKey:GWSOrderKey];
          if (coderOrder)
            {
              NSEnumerator *objEnum;
              id mutStr;
              NSString *key;
              BOOL isFirst;

              mutStr = [[NSMutableString alloc] init];
              isFirst = YES;
              objEnum = [coderOrder objectEnumerator];
              while ((key = [objEnum nextObject]))
                {
                  id val;

                  val = [fieldValueObj objectForKey:key];
                  if (val && [val length])
                    {
                      if (!isFirst)
                        [mutStr appendString:@", "];
                      else
                        isFirst = NO;
                      [mutStr appendString:val];
                    }
                }
              fieldValueStr = [NSString stringWithString:mutStr];
              [mutStr release];
            }
          else
            {
              NSLog(@"Dictionary with no coder order in loadObject: %@", fieldValueObj);
              fieldValueStr = [fieldValueObj className];
            }
        }
      else if ([fieldValueObj isKindOfClass:[DBSFDataType class]])
        {
          fieldValueStr = [(DBSFDataType *)fieldValueObj stringValue];
        }
      else if ([fieldValueObj isKindOfClass:[NSNumber class]])
        {
          fieldValueStr = [(NSNumber *)fieldValueObj stringValue];
        }
      else
        {
          /* unknown type */
          NSLog(@"%@ unknown type in loadObject: %@", fieldDevName, [fieldValueObj className]);
          fieldValueStr = [fieldValueObj className];
        }
      rowDict = [NSDictionary dictionaryWithObjectsAndKeys: 
        fieldDevName, COLID_DEVNAME,
        fieldLabel, COLID_LABEL,
        fieldValueStr, COLID_VALUE,
        NULL];
      [arrayRows addObject: rowDict];
      [filteredRows addObject:[NSNumber numberWithInt:i]];
    }
 
  [fieldTable reloadData];

  [winObjInspector setTitle: objDevName];
  [self resetUI:[NSDictionary dictionaryWithObjectsAndKeys:@"Loaded", DBOIStatusKey, nil]];
  [arp release];
}

- (void)performUpdateObject:(id)argObj
{
  NSUInteger i;
  NSMutableArray *fieldNames;
  NSAutoreleasePool *arp;
  NSUserDefaults *defaults;

  if (!updatedRows || [updatedRows count] == 0)
    return;
  
  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];

  fieldNames = [[NSMutableArray alloc] initWithCapacity:1];
  for (i = 0; i < [updatedRows count]; i++)
    {
      NSDictionary *fieldDict;
      NSString *fieldName;
      NSString *cellStr;
      NSString *fieldValueStr;

      fieldDict = [updatedRows objectAtIndex:i];
      fieldName = [fieldDict objectForKey:COLID_DEVNAME];
      cellStr = [fieldDict objectForKey:COLID_VALUE];
      fieldValueStr = [dbs interpretString:cellStr forField:fieldName forObject:[sObj name]];
      [sObj setValue:fieldValueStr forField:fieldName];
      [fieldNames addObject:fieldName];
    }

  [[sObj DBSoap] setRunAssignmentRules:[defaults boolForKey:@"RunAssignmentRules"]];

  NS_DURING
    [sObj storeValuesForFields: fieldNames];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
        [fieldNames release];
        [self resetUI:[NSDictionary dictionaryWithObjectsAndKeys:@"Update Error", DBOIStatusKey, nil]];
        [arp release];
        return;
      }
  NS_ENDHANDLER
  
  [fieldNames release];
  [updatedRows removeAllObjects];
  [fieldTable setNeedsDisplay:YES];
  [self resetUI:[NSDictionary dictionaryWithObjectsAndKeys:@"Updated", DBOIStatusKey, nil]];
  [arp release];
}

- (IBAction)loadObject:(id)sender
{
  [loadButton setEnabled:NO];
  [statusField setStringValue:@"Loading..."];
  [NSThread detachNewThreadSelector:@selector(performLoadObject:) toTarget:self withObject:nil];
}

- (IBAction)updateObject:(id)sender
{
  [loadButton setEnabled:NO];
  [updateButton setEnabled:NO];
  [statusField setStringValue:@"Updating..."];
  [NSThread detachNewThreadSelector:@selector(performUpdateObject:) toTarget:self withObject:nil];
}

 - (IBAction)search:(id)sender
{
  NSString *searchStr;
  NSUInteger i;

  searchStr = [searchField stringValue];
  [filteredRows removeAllObjects];
  if (searchStr && [searchStr length])
    {
      for (i = 0; i < [arrayRows count]; i++)
        {
          BOOL include;
          NSDictionary *row;

          row = [arrayRows objectAtIndex:i];
          include = NO;
          include |= [[row objectForKey:COLID_LABEL] rangeOfString:searchStr options:NSCaseInsensitiveSearch].location != NSNotFound;
          include |= [[row objectForKey:COLID_DEVNAME] rangeOfString:searchStr options:NSCaseInsensitiveSearch].location != NSNotFound;
          include |= [[row objectForKey:COLID_VALUE] rangeOfString:searchStr options:NSCaseInsensitiveSearch].location != NSNotFound;
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
    {
      NSString *str;

      [updateButton setEnabled:YES];
      str = [NSString stringWithFormat:@"Will update %lu fields", (unsigned long)[updatedRows count]];
      [statusField setStringValue:str];
    }
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
  NSUInteger i;
  NSUInteger originalRowIndex;

  originalRowIndex = [[filteredRows objectAtIndex:rowIndex] intValue];   
  
  originalRowDict = [arrayRows objectAtIndex: originalRowIndex];
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
    {
      [cell setDrawsBackground:YES];
      [cell setBackgroundColor:[NSColor colorWithDeviceRed:1.0 green:0.6 blue:0.6 alpha:1.0]];
    }
  else
    {
      [cell setDrawsBackground:NO];
    }

  if (!updateable)
    [cell setTextColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.8 alpha:1.0]];
  else
    [cell setTextColor:[NSColor blackColor]];

}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
  [arrayRows sortUsingDescriptors: [tableView sortDescriptors]];
  
  /* after sorting we need to recalculate filters */
  [self search:nil];
  
  [fieldTable reloadData];
}

@end

