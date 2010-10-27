/*
   Project: DataBasin

   Copyright (C) 2009-2010 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2009-01-13 00:36:45 +0100 by multix

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

#import "DBCVSWriter.h"

@implementation DBCVSWriter

- (id)initWithHandle:(NSFileHandle *)fileHandle
{
  if ((self = [super init]))
    {
      file = fileHandle;
      isQualified = NO;
      qualifier = @"\"";
      separator = @",";
      newLine = @"\n";
      encoding = NSUTF8StringEncoding;
   }
  return self;
}

- (void)setStringEncoding: (NSStringEncoding) enc
{
  encoding = enc;
}

- (void)setFieldNames:(NSArray *)array andWriteIt:(BOOL)flag
{
  if (flag == YES)
    {
      NSString *theLine;
      
      NSLog(@"should write out field names to file");
      theLine = [self formatOneLine:array];
      [file writeData: [theLine dataUsingEncoding: encoding]];
    }
}

- (void)writeDataSet:(NSArray *)array
{
  int i;
  int setCount;

  setCount = [array count];
  for (i = 0; i < setCount; i++)
    {
      NSString *oneLine;
      
      oneLine = [self formatOneLine:[array objectAtIndex:i]];
      [file writeData: [oneLine dataUsingEncoding: encoding]];
    }
}

- (NSString *)formatOneLine:(NSArray *)values
{
  NSMutableString *theLine;
  int      size;
  int      i;
  
  size = [values count];

  if (size == 0)
    return nil;

  theLine = [[NSMutableString alloc] initWithCapacity:64];
    
  for (i = 0; i < size-1; i++)
    {
      id obj;
      
      obj = [values objectAtIndex:i];
      if ([obj isKindOfClass: [NSDictionary class]])
        {
          [theLine appendString: @""];
          NSLog(@"Dictionary");
        }
      else if ([obj isKindOfClass: [NSString class]])
        {
          [theLine appendString: obj];
        }
      else
        NSLog(@"unknown class of value: %@", [obj class]);
      [theLine appendString: separator];
    }
  [theLine appendString:[values objectAtIndex:i]];
  [theLine appendString:newLine];
  return [theLine autorelease];
}

@end
