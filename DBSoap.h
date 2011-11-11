/*
   Project: DataBasin

   Copyright (C) 2008-2011 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2008-11-13 22:44:45 +0100 by multix

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
 
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
 
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <Foundation/Foundation.h>

#import <WebServices/WebServices.h>
#import "DBCVSWriter.h"
#import "DBCVSReader.h"

#define MAX_SOQL_SIZE 9000

@class DBSObject;

@interface DBSoap : NSObject
{
  GWSService *service;
    
  /* salesforce.com session variables */
  NSString     *sessionId;
  NSString     *serverUrl;
  BOOL         passwordExpired;
  NSDictionary *userInfo;

  /* list of all objects, custom and not */
  NSArray  *sObjectList;
  /* list of all object names, custom and not */
  NSMutableArray  *sObjectNamesList;
}

- (void)login :(NSURL *)url :(NSString *)userName :(NSString *)password :(BOOL)useHttps;

- (NSMutableArray *)queryFull :(NSString *)queryString queryAll:(BOOL)all;
- (NSString *)query :(NSString *)queryString queryAll:(BOOL)all toArray:(NSMutableArray *)objects;
- (NSString *)queryMore :(NSString *)locator toArray:(NSMutableArray *)objects;
- (void)queryIdentify :(NSString *)queryString with: (NSString *)identifier queryAll:(BOOL)all fromArray:(NSArray *)fromArray toArray:(NSMutableArray *)outArray withBatchSize:(int)batchSize;
- (void)create :(NSString *)objectName fromReader:(DBCVSReader *)reader;
- (void)update :(NSString *)objectName fromReader:(DBCVSReader *)reader;
- (NSMutableArray *)delete :(NSArray *)objectIdArray;
- (NSArray *)describeGlobal;
- (NSArray *)sObjects;
- (NSArray *)sObjectNames;
- (void)updateObjects;
- (DBSObject *)describeSObject: (NSString *)objectType;
- (NSString *)identifyObjectById:(NSString *)sfId;

- (NSString *) sessionId;
- (NSString *) serverUrl;
- (BOOL) passwordExpired;
- (NSDictionary *) userInfo;

@end


