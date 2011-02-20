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
  [fieldMatrix release];
  
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
  
  NSLog(@"Awaken");
  fieldMatrix = [[NSMatrix alloc] initWithFrame: NSZeroRect];
  [fieldMatrix setCellClass:[DBFieldCell class]];
/*  fieldMatrix = [[NSMatrix alloc] initWithFrame:NSZeroRect
                                           mode:NSRadioModeMatrix cellClass:[DBFieldCell class]
                                   numberOfRows:1 numberOfColumns:0]; */
  [fieldMatrix setAutosizesCells:YES];
  [fieldScrollView setDocumentView:fieldMatrix];
  
}

- (void)show
{
  if (winObjInspector == nil)
    [NSBundle loadNibNamed:@"ObjectInspector" owner:self];

  [winObjInspector makeKeyAndOrderFront:self];
}

- (IBAction)loadObject:(id)sender
{
  NSMutableArray *objInfoArray;
  NSString *statement;
  NSString *objId;
  int i;
  
  objId = [fieldObjId stringValue];
  statement = @"select Id from SObject where Id = '";
  statement = [statement stringByAppendingString: objId];
  statement = [statement stringByAppendingString: @"'"];
  objInfoArray = [[NSMutableArray alloc] init];
  NSLog(@"statement: %@", statement);
  [dbs query :statement queryAll:NO toArray:objInfoArray];
  NSLog(@"%@", objInfoArray);
  
  [objInfoArray release];
  
  NSMutableArray *array;
  array = [[NSMutableArray alloc] initWithCapacity:1];
  DBFieldCell *cell;
  cell = [[DBFieldCell alloc] initTextCell:@"Cell1"];
  [array addObject:cell];
  cell = [[DBFieldCell alloc] initTextCell:@"Cell2"];
  [array addObject:cell];
  if ([array count] >= [fieldMatrix numberOfRows])
    {
    NSLog(@"we need to make it bigger");
    while ([fieldMatrix numberOfRows] < [array count])
      [fieldMatrix addRow];
    }
  else
    while ([array count] < [fieldMatrix numberOfRows])
      [fieldMatrix removeRow:[fieldMatrix numberOfRows]];
  
  for (i = 0; i < [array count]; i++)
    [fieldMatrix putCell:[array objectAtIndex:i] atRow:i column:0];
  [fieldMatrix sizeToCells];  
}

@end
