/*
   Project: DataBasin

   Copyright (C) 2008-2011 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2011-11-08 22:44:45 +0100 by multix

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

@class DBSObject;
@class DBSoap;

@interface DBSoapCSV : NSObject
{
  DBSoap *db;
}

- (void)setDBSoap: (DBSoap *)dbs;
- (void)query :(NSString *)queryString queryAll:(BOOL)all toWriter:(DBCVSWriter *)writer;
- (void)queryIdentify :(NSString *)queryString queryAll:(BOOL)all fromReader:(DBCVSReader *)reader toWriter:(DBCVSWriter *)writer;
- (void)create :(NSString *)objectName fromReader:(DBCVSReader *)reader;
- (void)update :(NSString *)objectName fromReader:(DBCVSReader *)reader;
- (NSMutableArray *)deleteFromReader:(DBCVSReader *)reader;
- (void)describeSObject: (NSString *)objectType toWriter:(DBCVSWriter *)writer;


@end


