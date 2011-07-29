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
      [self setStringEncoding: NSUTF8StringEncoding];
      //      encoding = NSUTF8StringEncoding;
      //      bomLength = 3;
   }
  return self;
}

- (void)setStringEncoding: (NSStringEncoding) enc
{
  NSData *tempData;

  encoding = enc;
  bomLength = 0;

  /* BOM heuristics */
  tempData = [@" "dataUsingEncoding: encoding];
  tempData = [tempData subdataWithRange: NSMakeRange(0, [tempData length] - [@" " lengthOfBytesUsingEncoding: encoding])];
  bomLength = [tempData length];

  NSLog(@"bom length: %u", bomLength);
}

- (void)setFieldNames:(NSArray *)array andWriteIt:(BOOL)flag
{
  /* if we write the header, fine, else we write at least the BOM */

  if (flag == YES)
    {
      NSString *theLine;
      
      NSLog(@"should write out field names to file");
      theLine = [self formatOneLine:array];
      [file writeData: [theLine dataUsingEncoding: encoding]];
    }
  else
    {
      NSData *tempData;

      tempData = [@" "dataUsingEncoding: encoding];
      tempData = [tempData subdataWithRange: NSMakeRange(0, [tempData length] - [@" " lengthOfBytesUsingEncoding: encoding])];
      [file writeData: tempData];
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
      NSData *data;
      NSData *data2;
      
      oneLine = [self formatOneLine:[array objectAtIndex:i]];
      data = [oneLine dataUsingEncoding: encoding];
      if (bomLength > 0)
	data2 = [NSData dataWithBytesNoCopy: [data bytes]+bomLength length: [data length]-bomLength freeWhenDone: NO];
      else
	data2 = data;
      [file writeData: data2];
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
