/*
   Project: DataBasin

   Copyright (C) 2008-2011 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2011-11-08 22:44:45 +0100 by multix

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
 
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
 
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
 */

#import <AppKit/AppKit.h>

#import "DBSoap.h"
#import "DBSObject.h"
#import "DBSoapCSV.h"

@implementation DBSoapCSV

- (void)setDBSoap: (DBSoap *)dbs
{
  db = dbs;
}

- (void)query :(NSString *)queryString queryAll:(BOOL)all toWriter:(DBCVSWriter *)writer
{
  int            i;
  int            j;
  int            batchSize;

  NSString       *qLoc;
  NSMutableArray *sObjects;
  NSArray        *keys;
  
  
  sObjects = [[NSMutableArray alloc] init];

  qLoc = [db query: queryString queryAll: all toArray: sObjects];

  keys = nil;
  batchSize = [sObjects count];
  if (batchSize > 0)
    {
      DBSObject *obj;
      NSMutableArray *set;

      obj = [sObjects objectAtIndex: 0];
      keys = [obj fieldNames];
      [writer setFieldNames:keys andWriteIt:YES];

      set = [[NSMutableArray alloc] init];
      for (i = 0; i < batchSize; i++)
        {
          NSMutableArray *values;
	  DBSObject *record;
	  
          record = [sObjects objectAtIndex:i];
          values = [NSMutableArray arrayWithCapacity:[keys count]];
          for (j = 0; j < [keys count]; j++)
            {
              [values addObject:[record fieldValue: [keys objectAtIndex:j]]];
            }
          [set addObject:values];
        }
      [writer writeDataSet:set];
      [set release];
    }

  while (qLoc != nil)
    {
      NSMutableArray *set;

      [sObjects removeAllObjects];
      NSLog(@"size %d", [sObjects count]);
      qLoc = [db queryMore: qLoc toArray: sObjects];
      batchSize = [sObjects count];
      set = [[NSMutableArray alloc] init];
      for (i = 0; i < batchSize; i++)
        {
          NSMutableArray *values;
	  DBSObject *record;
	  
          record = [sObjects objectAtIndex:i];
          values = [NSMutableArray arrayWithCapacity:[keys count]];
          for (j = 0; j < [keys count]; j++)
            {
              [values addObject:[record fieldValue: [keys objectAtIndex:j]]];
            }
          [set addObject:values];
        }
      [writer writeDataSet:set];
      [set release];      
    }
  [sObjects release];
}

/**
   See DBSoap for informations about the batch size parameter.
 */
- (void)queryIdentify :(NSString *)queryString queryAll:(BOOL)all fromReader:(DBCVSReader *)reader toWriter:(DBCVSWriter *)writer withBatchSize:(int)bSize
{
  NSArray *inFieldNames;
  unsigned inFieldCount;
  NSArray *dataSet;
  NSMutableArray *identifierArray;
  NSMutableArray *sObjects;
  NSString *identifier;
  unsigned i;
  unsigned j;
  unsigned batchSize;
  NSArray *keys;

  /* retrieve objects to create */
  NSLog(@"CVS identify 1.....");
  
  /* first the fields */
  inFieldNames = [reader fieldNames];
  inFieldCount = [inFieldNames count];
  dataSet = [reader readDataSet];
  NSLog(@"field names: %@", inFieldNames);
  if (inFieldCount > 1)
    {
      NSLog(@"We cannot identify %d field", inFieldCount);
      return;
    }
  identifierArray = [[NSMutableArray arrayWithCapacity: [dataSet count]] retain];
  for (i = 0; i < [dataSet count]; i++)
    [identifierArray addObject: [[dataSet objectAtIndex: i] objectAtIndex: 0]];
  sObjects = [[NSMutableArray alloc] init];
  identifier = [inFieldNames objectAtIndex: 0];
  NSLog(@"identify through %@", identifier);

  [db queryIdentify:queryString with:identifier queryAll:all fromArray:identifierArray toArray: sObjects withBatchSize:bSize];

  keys = nil;
  batchSize = [sObjects count];
  if (batchSize > 0)
    {
      DBSObject *obj;
      NSMutableArray *set;

      obj = [sObjects objectAtIndex: 0];
      keys = [obj fieldNames];
      [writer setFieldNames:keys andWriteIt:YES];

      set = [[NSMutableArray alloc] init];
      for (i = 0; i < batchSize; i++)
        {
          NSMutableArray *values;
	  DBSObject *record;
	  
          record = [sObjects objectAtIndex:i];
          values = [NSMutableArray arrayWithCapacity:[keys count]];
          for (j = 0; j < [keys count]; j++)
            {
              [values addObject:[record fieldValue: [keys objectAtIndex:j]]];
            }
          [set addObject:values];
        }
      [writer writeDataSet:set];
      [set release];
    }

  [sObjects release];
  [identifierArray release];
}

- (void)create :(NSString *)objectName fromReader:(DBCVSReader *)reader
{
  NSEnumerator          *enumerator;
  NSArray               *objectsArray;
  NSArray               *fieldValues;
  NSArray               *fieldNames;
  int                   fieldCount;
  NSMutableArray        *sObjectsArray;

  /* retrieve objects to create */
  
  /* first the fields */
  fieldNames = [reader fieldNames];
  fieldCount = [fieldNames count];
  objectsArray = [reader readDataSet];
  

  sObjectsArray = [[NSMutableArray arrayWithCapacity: [objectsArray count]] retain];
  
  enumerator = [objectsArray objectEnumerator];
  while ((fieldValues = [enumerator nextObject]))
  {
    unsigned int i;
    DBSObject *sObj;

    sObj = [[DBSObject alloc] init];
  
    for (i = 0; i < fieldCount; i++)
      [sObj setValue: [fieldValues objectAtIndex:i] forField: [fieldNames objectAtIndex:i]];
 
    [sObjectsArray addObject: sObj];
    [sObj release];
  }

  [db create:objectName fromArray:sObjectsArray];
  [sObjectsArray release];
}

- (void)update :(NSString *)objectName fromReader:(DBCVSReader *)reader
{
  NSEnumerator          *enumerator;
  NSArray               *objectsArray;
  NSArray               *fieldValues;
  NSArray               *fieldNames;
  int                   fieldCount;
  NSMutableArray        *sObjectsArray;

  /* retrieve objects to update */
  
  /* first the fields */
  fieldNames = [reader fieldNames];
  fieldCount = [fieldNames count];
  objectsArray = [reader readDataSet];
  

  sObjectsArray = [[NSMutableArray arrayWithCapacity: [objectsArray count]] retain];
  
  enumerator = [objectsArray objectEnumerator];
  while ((fieldValues = [enumerator nextObject]))
  {
    unsigned int i;
    DBSObject *sObj;

    sObj = [[DBSObject alloc] init];
  
    for (i = 0; i < fieldCount; i++)
      [sObj setValue: [fieldValues objectAtIndex:i] forField: [fieldNames objectAtIndex:i]];
 
    [sObjectsArray addObject: sObj];
    [sObj release];
  }

  [db update:objectName fromArray:sObjectsArray];
  [sObjectsArray release];
}

- (void)describeSObject: (NSString *)objectType toWriter:(DBCVSWriter *)writer
{
  int            i;
  int            size;
  DBSObject      *object;
  NSDictionary   *properties;
  NSArray        *fields;
  NSArray        *keys;
  NSMutableArray *set;

  
  object = [db describeSObject: objectType];
  fields = [object fieldNames];
  size = [fields count];
  
  if (size < 1)
    return;
  
  keys = [[object propertiesOfField: [fields objectAtIndex: 0]] allKeys];
  [writer setFieldNames:[NSArray arrayWithArray:keys] andWriteIt:YES];
  
  set = [[NSMutableArray alloc] init];
  
  for (i = 0; i < size; i++)
    {
      NSMutableArray *values;
      int            j;
      NSString       *field;
      
      field = [fields objectAtIndex: i];
      properties = [object propertiesOfField: field];
      values = [NSMutableArray arrayWithCapacity:[keys count]];
      for (j = 0; j < [keys count]; j++)
        {
          id       obj;
          id       value;
          NSString *key;
      
          key = [keys objectAtIndex:j];
          obj = [properties objectForKey: key];
      
          value = obj;
          [values addObject:value];
        }
      [set addObject:values];
    }
  [writer writeDataSet:set];
  [set release];
}



- (NSMutableArray *)deleteFromReader:(DBCVSReader *)reader
{
  NSMutableArray *objectsArray;
  NSMutableArray *resultArray;

  /* retrieve objects to delete */
  // FIXME perhaps this copy is useless
  objectsArray = [[NSMutableArray arrayWithArray:[reader readDataSet]] retain];
  NSLog(@"objects to delete: %@", objectsArray);
  NSLog(@"count of objects to delete: %d", [objectsArray count]);

  resultArray = [db delete:objectsArray];
  [objectsArray release];
  return resultArray;
}


- (void)dealloc
{
  [super dealloc];
}

@end
