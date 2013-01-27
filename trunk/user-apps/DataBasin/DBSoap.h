/*
   Project: DataBasin

   Copyright (C) 2008-2013 Free Software Foundation

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

#import "DBLogger.h"

#define MAX_SOQL_SIZE 9000
#define MAX_BATCH_SIZE 200

@class DBSObject;
@protocol DBProgressProtocol;

@interface DBSoap : NSObject
{
  GWSService *service;
  DBLogger *logger;
    
  /* salesforce.com session variables */
  NSString     *sessionId;
  NSString     *serverUrl;
  BOOL         passwordExpired;
  NSDictionary *userInfo;

  /* list of all objects, custom and not */
  NSArray  *sObjectList;
  /* list of all object names, custom and not */
  NSMutableArray  *sObjectNamesList;

  /* create, update, upsert batch size */
  unsigned upBatchSize;

  /** Timeout in seconds, for generic methods */
  unsigned standardTimeoutSec;

  /** Timeout in seconds, for query methods */
  unsigned queryTimeoutSec;
}

- (void)login :(NSURL *)url :(NSString *)userName :(NSString *)password :(BOOL)useHttps;
- (void)setLogger: (DBLogger *)l;
- (DBLogger *)logger;

- (NSMutableArray *)queryFull :(NSString *)queryString queryAll:(BOOL)all progressMonitor:(id<DBProgressProtocol>)p;
- (NSString *)query :(NSString *)queryString queryAll:(BOOL)all toArray:(NSMutableArray *)objects progressMonitor:(id<DBProgressProtocol>)p;
- (NSString *)queryMore :(NSString *)locator toArray:(NSMutableArray *)objects;
- (void)queryIdentify :(NSString *)queryString with: (NSArray *)identifiers queryAll:(BOOL)all fromArray:(NSArray *)fromArray toArray:(NSMutableArray *)outArray withBatchSize:(int)batchSize progressMonitor:(id<DBProgressProtocol>)p;
- (void)create :(NSString *)objectName fromArray:(NSMutableArray *)objects progressMonitor:(id<DBProgressProtocol>)p;
- (void)update :(NSString *)objectName fromArray:(NSMutableArray *)objects progressMonitor:(id<DBProgressProtocol>)p;
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

- (void)setStandardTimeout:(unsigned)sec;
- (void)setQueryTimeout:(unsigned)sec;
- (unsigned)standardTimeout;
- (unsigned)queryTimeout;

@end

