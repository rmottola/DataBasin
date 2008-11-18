/*
   Project: DataBasin

   Copyright (C) 2008 Free Software Foundation

   Author: Riccardo Mottola,,,

   Created: 2008-11-13 22:44:45 +0100 by multix

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

#import "DBSoap.h"


@implementation DBSoap

- (void)login :(NSString *)userName :(NSString *)password
{
  GWSSOAPCoder          *coder;
  NSUserDefaults        *defs;
  NSMutableArray        *orderArray;
  NSMutableDictionary   *parmsDict;
  NSURL                 *url;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;


  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults:
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"80", @"Port",
      nil]
    ];
    
    NSLog(@"init service");
    service = [[GWSService alloc] init];
    
    NSLog(@"init coder");
    coder = [GWSSOAPCoder new];


  [service setCoder:coder];
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [parmsDict setObject: userName forKey: @"username"];
  [parmsDict setObject: password forKey: @"password"];

  orderArray = [NSMutableArray arrayWithCapacity: 1];
  [orderArray addObject: @"login"];
  
  url = [NSURL URLWithString:@"https://www.salesforce.com/services/Soap/c/14.0"];
  [service setURL:url];
  resultDict = [service invokeMethod: @"login"
                parameters : parmsDict
		order : nil
		timeout : 30];

  NSLog(@"dict is %d big", [resultDict count]);
  
  enumerator = [resultDict keyEnumerator];
  while (key = [enumerator nextObject])
  {
    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
  }
  
  [coder release];
}

@end
