/*
   Project: DataBasin

   Copyright (C) 2012 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2012-10-19 09:32:13 +0000 by multix

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

@protocol DBProgressProtocol <NSObject>

/** Sets the maximum value expected on which to calculate progress on.<br>
    E.g. it could be the maximum expected number of records.
  */
-(void)setMaximumValue:(NSUInteger)max;

/** Sets the current progress, e.g. the current count */
-(void)setCurrentValue:(NSUInteger)current;

/** Forces completion */
-(void)setEnd;

/** Sets a description of the current phase */
-(void)setCurrentDescription:(NSString *)desc;

@end
