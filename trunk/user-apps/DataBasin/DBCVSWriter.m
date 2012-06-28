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
      isQualified = YES;
      qualifier = @"\"";
      separator = @",";
      newLine = @"\n";
      [self setStringEncoding: NSUTF8StringEncoding];
      //      encoding = NSUTF8StringEncoding;
      //      bomLength = 3;
   }
  return self;
}

- (void)setIsQualified: (BOOL)flag
{
  isQualified = flag;
}

- (BOOL)isQualified
{
  return isQualified;
}

- (void)setStringEncoding: (NSStringEncoding) enc
{
  NSData *tempData;

  encoding = enc;
  bomLength = 0;

  /* BOM heuristics */
  tempData = [@" "dataUsingEncoding: encoding];
#if defined(__APPLE__) && (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
  NSString *blankString;
    
  blankString = [[[NSString alloc] initWithBytes: [tempData bytes] length: [tempData length] encoding: encoding] autorelease];
  NSLog(@"blank string: %@", blankString);
  tempData = [tempData subdataWithRange: NSMakeRange(0, [tempData length] - [blankString length])];
#else
  tempData = [tempData subdataWithRange: NSMakeRange(0, [tempData length] - [@" " lengthOfBytesUsingEncoding: encoding])];
#endif
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
      tempData = [tempData subdataWithRange: NSMakeRange(0, bomLength)];
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
  NSString *escapedQualifier;
  int      size;
  int      i;
  id obj;
  
  size = [values count];

  if (size == 0)
    return nil;

  escapedQualifier = [qualifier stringByAppendingString: qualifier];

  theLine = [[NSMutableString alloc] initWithCapacity:64];

  for (i = 0; i < size; i++)
    { 
      obj = [values objectAtIndex:i];
      if ([obj isKindOfClass: [NSDictionary class]])
        {
          [theLine appendString: @""];
          NSLog(@"Dictionary");
        }
      else if ([obj isKindOfClass: [NSString class]])
        {
	  if (isQualified)
	    {
	      NSMutableString *s;

	      s = [[NSMutableString alloc] initWithCapacity: [obj length]+2];
	      [s appendString: qualifier]; 
	      [s appendString: obj];

	      [s replaceOccurrencesOfString: qualifier withString: escapedQualifier options:(unsigned)NULL range: NSMakeRange(1, [s length]-1)];
	      [s appendString: qualifier];

	      [theLine appendString: s];
	      [s release];
	    }
	  else
	    {
	      [theLine appendString: obj];
	    }
        }
      else if ([obj isKindOfClass: [NSNumber class]])
	{
	  // FIXME: this is locale sensitive?
	  // FIXME2: maybe give the option to quote also numbers

	  [theLine appendString: [obj stringValue]];
	}
      else
        NSLog(@"unknown class of value: %@", [obj class]);

      if (i < size-1)
	[theLine appendString: separator];
    }

  [theLine appendString:newLine];
  return [theLine autorelease];
}

@end
