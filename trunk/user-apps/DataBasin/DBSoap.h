/*
   Project: DataBasin

   Copyright (C) 2008-2009 Free Software Foundation

   Author: Riccardo Mottola

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

#import <Foundation/Foundation.h>

#import <WebServices/WebServices.h>
#import "DBCVSWriter.h"

@interface DBSoap : NSObject
{
    GWSService *service;
    
    /* salesforce.com session variables */
    NSString  *sessionId;
    NSString  *serverUrl;
}

- (void)login :(NSURL *)url :(NSString *)userName :(NSString *)password;
- (void)query :(NSString *)queryString toWriter:(DBCVSWriter *)writer;
- (void)queryMore :(NSString *)queryLocator toWriter:(DBCVSWriter *)writer;

- (NSString *) sessionId;
- (NSString *) serverUrl;

@end


