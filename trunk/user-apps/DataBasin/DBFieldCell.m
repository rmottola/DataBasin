/*
 Project: DataBasin
 
 Copyright (C) 2011 Free Software Foundation
 
 Author: Riccardo Mottola
 
 Created: 2011-02-08
 
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

#import "DBFieldCell.h"


@implementation DBFieldCell

/* Overridden */
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  NSMutableParagraphStyle *style;
  NSDictionary *strAttr;
  NSPoint cellOrigin;
  float cellWidth;
  NSPoint labelPoint;
  NSPoint devnamePoint;
  NSPoint valuePoint;

  cellOrigin = cellFrame.origin;
  cellWidth = cellFrame.size.width;
  labelPoint = cellOrigin;
  devnamePoint = NSMakePoint(labelPoint.x + cellWidth/3, cellOrigin.y);
  valuePoint = NSMakePoint(devnamePoint.x + cellWidth/3, cellOrigin.y);
  
  strLabel = @"Label";
  strDevName = @"DevName";

  NSLog(@"cell width: %f", cellWidth);
  style = [[NSMutableParagraphStyle alloc] init];
  [style setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
  strAttr = [[NSDictionary dictionaryWithObjectsAndKeys:
    [NSFont labelFontOfSize:-1], NSFontAttributeName,
    style, NSParagraphStyleAttributeName, nil] retain];
 
  [strLabel drawAtPoint:labelPoint withAttributes:strAttr];
  [strDevName drawAtPoint:devnamePoint withAttributes:strAttr];
  [[self stringValue] drawAtPoint:valuePoint withAttributes:strAttr];
  [strAttr release];
}

@end
