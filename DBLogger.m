/*
   Project: DataBasin

   Copyright (C) 2012 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2012-04-24 10:50:19 +0000 by multix

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

#import "DBLogger.h"

@implementation DBLogger

- (id)init
{
  if ((self = [super init]))
    {
      [NSBundle loadNibNamed:@"Log" owner:self];
      logLevel = LogStandard;
    }
  return self;
}

-(void)dealloc
{
  [super dealloc];
}

-(void)setLogLevel: (DBLogLevel)l
{
  logLevel = l;
}


- (IBAction)show:(id)sender
{
  [logWin makeKeyAndOrderFront:self];
}

-(void)log: (DBLogLevel)level :(NSString* )format, ...
{
  va_list ap;
  NSString *formattedString;

  if (logLevel >= level)
    {
      va_start (ap, format);
      formattedString = [[NSString alloc] initWithFormat:format arguments: ap];
      va_end(ap);
  
  
      NSLog(@"level: %d | %@", level, formattedString);
      [formattedString release];
    }
}

@end
