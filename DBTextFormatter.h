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

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import <Foundation/Foundation.h>

#if !defined (GNUSTEP) &&  (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
#ifndef NSUInteger
#define NSUInteger unsigned
#endif
#endif

@interface DBTextFormatter : NSFormatter
{
  NSUInteger maxLength;
  BOOL restrictNewLine;
}

- (NSUInteger)maxLength;
- (void)setMaxLength:(NSUInteger)l;

@end


