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
#import "DBSObject.h"

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

- (NSString *)formatScalarObject:(id)value
{
  NSString *res;
  NSString *escapedQualifier;

  escapedQualifier = [qualifier stringByAppendingString: qualifier];

  res = nil;
  if ([value isKindOfClass: [NSString class]])
    {
      if (isQualified)
	{
	  NSMutableString *s;

	      
	  s = [[NSMutableString alloc] initWithCapacity: [value length]+2];

	  [s appendString: qualifier]; 

	  [s appendString: value];

	  [s replaceOccurrencesOfString: qualifier withString: escapedQualifier options:(unsigned)NULL range: NSMakeRange(1, [s length]-1)];
	  [s appendString: qualifier];

	  res = [NSString stringWithString: s];
	  [s release];
	}
      else
	{
	  res = value;
	}
    }
  else if ([value isKindOfClass: [NSNumber class]])
    {
      // FIXME: this is locale sensitive?
      // FIXME2: maybe give the option to quote also numbers
      if (isQualified)
	{
	  NSMutableString *s;
	  s = [[NSMutableString alloc] initWithCapacity: [value length]+2];
	  
	  [s appendString: qualifier];
	  [s appendString: [value stringValue]];
	  res = [NSString stringWithString: s];
	  [s release];
	}
      else
	{
	  res = [value stringValue];
	}
    }

  return res;
}

- (NSString *)formatComplexObject:(NSMutableDictionary *)d withRoot:(NSString *)root forHeader:(BOOL) headerFlag
{
  NSMutableArray  *keys;
  unsigned i;
  NSMutableString *tempRes;
  NSString *escapedQualifier;

  if (!d)
    return nil;

  escapedQualifier = [qualifier stringByAppendingString: qualifier];

  keys = [NSMutableArray arrayWithArray:[d allKeys]];
  [keys removeObject:@"GWSCoderOrder"];
  
  /* remove some fields which get added automatically by salesforce even if not asked for */
  [keys removeObject:@"type"];
  
  /* remove Id only if it is null, else an array of two populated Id is returned by SF */
  if (![[d objectForKey:@"Id"] isKindOfClass: [NSArray class]])
    [keys removeObject:@"Id"];

  //[logger log: LogDebug :@"[DBCSVWriter formatComplexObject] clean dictionary %@:\n", d];
  NSLog(@"[DBCSVWriter formatComplexObject] clean dictionary %@\n", d);

  tempRes = [[NSMutableString alloc] initWithCapacity: [keys count]];
  for (i = 0; i < [keys count]; i++)
    {
      id obj;
      NSString *key;
      
      key = [keys objectAtIndex: i];
      obj = [d objectForKey: key];
      if ([key isEqualToString:@"Id"])
	obj = [obj objectAtIndex: 0];
      
      if ([obj isKindOfClass: [NSDictionary class]])
        {
	  NSMutableString *s;

	  s = [NSMutableString stringWithString:root];
	  if (headerFlag)
	    {
	      [s appendString:@"."];
	      [s appendString:key];
	    }

          [tempRes appendString: [self formatComplexObject: obj withRoot:s forHeader:headerFlag]];
        }
      else if ([obj isKindOfClass: [NSString class]] || [obj isKindOfClass: [NSNumber class]])
        {
	  NSMutableString *s;

	  if (headerFlag)
	    {
	      s = [NSMutableString stringWithString:root];
	      [s appendString:@"."];
	      [s appendString:key];
	    }
	  else
	    s = obj;
	  [tempRes appendString: [self formatScalarObject:s]];
	}
      else
	NSLog(@"[DBCSVWriter formatComplexObject] unknown class of value: %@, object: %@", [obj class], obj);
      
      if (i < [keys count]-1)
	[tempRes appendString: separator];
    }
  return [tempRes autorelease];
}

- (void)setFieldNames:(id)obj andWriteIt:(BOOL)flag
{
  /* if we write the header, fine, else we write at least the BOM */

  if (flag == YES)
    {
      NSString *theLine;
      NSArray *array;

      NSLog(@"should write out field names to file");

      /* if we have just a single object, we fake an array */
      if([obj isKindOfClass: [NSArray class]])
	array = obj;
      else
	array = [NSArray arrayWithObject: obj];

      theLine = [self formatOneLine:array forHeader:YES];      
      NSLog(@"array of header: %@\n", array);
      theLine = [self formatOneLine:array forHeader:YES];
      NSLog(@"--- end of header formatting \n");
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
      id o;

      NSLog(@"write data set");
      o = [array objectAtIndex:i];
      if ([o isKindOfClass: [DBSObject class]])
	o = [NSArray  arrayWithObject: o];
      oneLine = [self formatOneLine:o forHeader:NO];
      data = [oneLine dataUsingEncoding: encoding];
      if (bomLength > 0)
	data2 = [NSData dataWithBytesNoCopy: [data bytes]+bomLength length: [data length]-bomLength freeWhenDone: NO];
      else
	data2 = data;
      [file writeData: data2];
    }
}

- (NSString *)formatOneLine:(NSArray *)values forHeader:(BOOL) headerFlag
{
  NSMutableString *theLine;
  NSString *escapedQualifier;
  int      size;
  int      i;
  id       obj;
  
  NSLog(@"Format one line array: %@", values);

  size = [values count];

  if (size == 0)
    return nil;

  escapedQualifier = [qualifier stringByAppendingString: qualifier];

  theLine = [[NSMutableString alloc] initWithCapacity:64];
  NSLog(@"format one line");
  for (i = 0; i < size; i++)
    {
      obj = [values objectAtIndex:i];
      if ([obj isKindOfClass: [NSDictionary class]])
        {
          NSLog(@"Dictionary: %@", obj);
	  [theLine appendString: [self formatComplexObject: obj withRoot: nil forHeader:headerFlag]];
        }
      if ([obj isKindOfClass: [DBSObject class]])
        {
	  NSArray *keys;
	  unsigned j;
	  NSMutableArray *values;

	  NSLog(@"DBSObject at root level");

	  keys = [obj fieldNames];

	  values = [NSMutableArray arrayWithCapacity:[keys count]];
          for (j = 0; j < [keys count]; j++)
            {
	      NSString *key;
	      id value;

	      key = [keys objectAtIndex: j];
	      value = [obj fieldValue: key];
	      NSLog(@"key ---> %@ object %@", key, value);
	      
	      if ([value isKindOfClass: [NSString class]])
		{
		  NSLog(@"String");
		  if (headerFlag)
		    {
		      [theLine appendString: [self formatScalarObject:key]];
		    }
		  else
		    {
		      [theLine appendString: [self formatScalarObject:value]];
		    }
		}
	      else if ([value isKindOfClass: [NSDictionary class]])
		{
		  NSLog(@"Dictionary");
		  [theLine appendString: [self formatComplexObject:value withRoot:key forHeader:headerFlag]];
		}
	      else
		{
		  NSLog(@"unknown class for object: %@", value);
		}

	      if (j < [keys count]-1)
		[theLine appendString: separator];
	    }
	}
      else if ([obj isKindOfClass: [NSString class]])
        {
	  [theLine appendString: [self formatScalarObject: obj]];
        }
      else if ([obj isKindOfClass: [NSNumber class]])
	{
	  [theLine appendString: [self formatScalarObject: obj]];
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
