/*
   Project: DataBasin

   Copyright (C) 2014 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2014-09-19 17:38:07 +0200 by multix

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

#import "DBTextFormatter.h"

@implementation DBTextFormatter

- (id)init
{
  if ((self = [super init]))
    {
      maxLength = 0;
    }
  return self;
}

- (NSUInteger)maxLength
{
  return maxLength;
}

- (void)setMaxLength:(NSUInteger)l
{
  maxLength = l;
}

- (NSString *)stringForObjectValue:(id)anObject
{
  NSString *str;
  
  if (![anObject isKindOfClass:[NSString class]])
    return nil;
    
  str = (NSString *)anObject;
  return [NSString stringWithString:str];
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
  BOOL returnValue = NO;
  NSString *newS;
  
  newS = [NSString stringWithString:string];
  if (maxLength > 0 && [newS length] > maxLength)
    newS = [newS substringToIndex:maxLength];

  returnValue = YES;
  if(obj)
    *obj = newS;

  return returnValue;
}

@end
