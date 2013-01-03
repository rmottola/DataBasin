/*
   Project: DataBasin

   Copyright (C) 2012-2013 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2012-10-19 09:34:49 +0000 by multix

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

#import "DBProgress.h"
#import "DBLogger.h"

@implementation DBProgress

-(void)dealloc
{
  [startDate release];
  [super dealloc];
}

/* protocol methods */
- (void)setLogger:(DBLogger *)l
{
  logger = l;
}

-(void)reset
{
  maxVal = 0;
  currVal = 0;
  percent = 0;
  currentDescription = @"";
  [startDate release];
  startDate = [[NSDate date] retain];
}

-(void)setMaximumValue:(unsigned long)max
{
  maxVal = max;
  [logger log:LogDebug :@"[DBProgress] maximum: %lu\n", maxVal];
}

-(void)setCurrentValue:(unsigned long)current
{
  NSTimeInterval timeDelta;
  NSTimeInterval totalTime;
  NSTimeInterval remainingTime;
  NSDate *endDate;


  currVal = current;
  NSLog(@"set %lu", currVal);
  /* if we don't have a maximum value, we continuously shift it to the current one */
  if (maxVal == 0)
    maxVal = currVal;

  [logger log:LogDebug :@"[DBProgress] current: %lu\n", currVal];
  percent = (double)(currVal * 100) / (double)maxVal;
  remainingTime = 0;
  if (currVal > 0)
    {
      timeDelta = [[NSDate date] timeIntervalSinceDate:startDate];
      totalTime = (timeDelta * maxVal) / (double)currVal;
      remainingTime = totalTime-timeDelta;
      endDate = [NSDate dateWithTimeIntervalSinceNow: remainingTime];
      NSLog(@"start %@ end date: %@", startDate, endDate);
    }
  [logger log:LogStandard :@"[DBProgress]: %f, time to completion: %lf\n", percent, remainingTime];
}

-(void)incrementCurrentValue:(unsigned long)amount
{
  NSLog(@"increment %lu", amount);
  if (amount == 0)
    return;
  [logger log:LogDebug :@"[DBProgress] amount: %lu\n", amount];
  [self setCurrentValue:(currVal+amount)];
}

-(void)setEnd
{
  percent = 100.0;
  [logger log:LogDebug :@"[DBProgress]: %f\n", percent];
}


-(void)setCurrentDescription:(NSString *)desc
{
  currentDescription = desc;
  [logger log:LogStandard :@"[DBProgress]:[%@]\n", currentDescription];
}

@end
