/*
 Project: DataBasin
 DBSobject.h
 
 Copyright (C) 2010-2012 Free Software Foundation
 
 Author: Riccardo Mottola
 
 Created by Riccardo Mottola on 20/07/10.
 
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

@class DBSoap;

@interface DBSObject : NSObject
{
  DBSoap  *dbs;

  NSMutableDictionary *recordValues;
  NSMutableArray      *fieldNames;
  NSMutableDictionary *fieldProperties;
  NSMutableDictionary *objectProperties;
}

/** returns the 18-char version of the 15-char id */
+ (NSString *)idTo18: (NSString *) id15;

/** returns the salesforce Id of the object in whichever format it is */
- (NSString *)sfId;

/** returns the salesforce Id of the object, always in the 15-char case-sensitive version */
- (NSString *)sfId15;

/** returns the salesforce Id of the object, always in the 18-char case-insensitive version */
- (NSString *)sfId18;

/** sets the properties of the object itself */
- (void)setObjectProperties: (NSDictionary *)properties;

/** returns the properties of the object itself, like its name */
- (NSDictionary *)objectProperties;

/** Set the soap database interface */
- (void)setDBSoap: (DBSoap *)db;

/** shortcut to return the property "name" */
- (NSString *)name;

- (void)setProperties: (NSDictionary *)properties forField: (NSString *)field;
- (NSDictionary *)propertiesOfField: (NSString *)field;

- (NSArray *)fieldNames;
- (id)fieldValue: (NSString *)field;
- (void)setValue: (id)value forField:(NSString *)field;

/** <p>Loads or refreshes the value of all known fields to the object.</p>
 *  <p>If the object is instantiated as a result of a describe, it will load all values.</p>
 *  <p>The object needs to have a valid <em>DBSoap</em> instance set </p>
 */
- (void)loadFieldValues;

/** <p>Loads or refreshes the value of the fields passed in the array.</p>
 */
- (void)loadValuesForFields:(NSArray *)namesArray;

@end