/*
   Project: DataBasin

   Copyright (C) 2009 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2009-06-24 22:34:06 +0200 by multix

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

#import "DBCVSReader.h"


@implementation DBCVSReader

- (id)initWithPath:(NSString *)filePath
{
  if ((self = [super init]))
    {
      NSString *fileContentString;
      isQualified = NO;
      qualifier = @"\"";
      separator = @",";
      newLine = @"\n";
      fileContentString = [NSString stringWithContentsOfFile:filePath];
      linesArray = [[fileContentString componentsSeparatedByString:newLine] retain];
      currentLine = 0;
   }
  return self;
}

- (void)dealloc
{
  [linesArray release];
  [super dealloc];
}

- (NSArray *)getFieldNames:(NSString *)firstLine
{
  NSScanner      *scanner;
  NSMutableArray *record;
  NSString       *field;
  
  scanner = [NSScanner scannerWithString:firstLine];
  record = [NSMutableArray arrayWithCapacity:1];
  NSLog(@"title line: %@", firstLine);

  while([scanner scanUpToString:separator intoString:&field] == YES)
    {
      NSLog(@"field: %@", field);
      [record addObject:field];
    }
  if([scanner scanUpToString:nil intoString:&field] == YES)
    {
      NSLog(@"field: %@", field);
      [record addObject:field];
    }
    
  NSLog(@"header %@", record);
  return record;
}

- (NSArray *)readDataSet:(NSString *)string
{
  return nil;
}

- (NSArray *)decodeOneLine:(NSString *)line
{
  NSScanner      *scanner;
  NSMutableArray *record;
  NSString       *field;
  
  scanner = [NSScanner scannerWithString:line];
  record = [NSMutableArray arrayWithCapacity:1];
  NSLog(@"data line: %@", line);
  
  while([scanner scanUpToString:separator intoString:&field] == YES)
    {
      NSLog(@"field: %@", field);
      [record addObject:field];
    }
  if([scanner scanUpToString:nil intoString:&field] == YES)
    {
      NSLog(@"field: %@", field);
      [record addObject:field];
    }
  
  NSLog(@"line %@", record);
  return record;
}

- (NSString *)readLine
{
  if (currentLine <= [linesArray count])
    {
      NSLog(@"line %@", [linesArray objectAtIndex:currentLine++]);
      return [linesArray objectAtIndex:currentLine++];
    }
  return nil;
}

@end
