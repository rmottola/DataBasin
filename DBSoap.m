/*
   Project: DataBasin

   Copyright (C) 2008-2010 Free Software Foundation

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

#import <AppKit/AppKit.h>

#import "DBSoap.h"




@implementation DBSoap

- (void)login :(NSURL *)url :(NSString *)userName :(NSString *)password
{
  GWSSOAPCoder          *coder;
  NSUserDefaults        *defs;
  NSMutableArray        *orderArray;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *loginParmDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;
  NSDictionary          *loginResult;
  NSDictionary          *loginResult2;
  NSDictionary          *userInfoResult;
  NSDictionary          *queryFault;


  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults:
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"80", @"Port",
      nil]
    ];
    
  NSLog(@"init service");

  /* initialize the coder */
  coder = [GWSSOAPCoder new];
  
  /* salesforce WSDL specifies it to be literal */
  [coder setUseLiteral:YES];

  /* init our service */
  service = [[GWSService alloc] init];
  
  [service setCoder:coder];
  
  /* set the SOAP action to an empty string, salesforce likes that more */
  [service setSOAPAction:@"\"\""];

  [service setURL:url];
  
//  [service setDebug:YES];
  
  
  /* prepare the parameters */
  loginParmDict = [NSMutableDictionary dictionaryWithCapacity: 3];
  [loginParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  [loginParmDict setObject: userName forKey: @"username"];
  [loginParmDict setObject: password forKey: @"password"];

  orderArray = [NSMutableArray arrayWithCapacity: 2];
  [orderArray addObject: @"username"];
  [orderArray addObject: @"password"];
  [loginParmDict setObject: orderArray forKey: GWSOrderKey];
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: loginParmDict forKey: @"login"];

  
  /* invoke the login */  
  resultDict = [service invokeMethod: @"login"
                parameters : parmsDict
		order : nil
		timeout : 60];

  NSLog(@"dict is %d big", [resultDict count]);
  
  enumerator = [resultDict keyEnumerator];
/*  while ((key = [enumerator nextObject]))
  {
    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
  } */
  

//  NSLog(@"request: %@", [[NSString alloc] initWithData:
//    	[resultDict objectForKey:@"GWSCoderRequestData"] encoding: NSUTF8StringEncoding]);
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
  {
    NSString *faultCode;
    NSString *faultString;
    
    
    faultCode = [queryFault objectForKey:@"faultcode"];
    faultString = [queryFault objectForKey:@"faultstring"];
    NSLog(@"fault code: %@", faultCode);
    NSLog(@"fault String: %@", faultString);
    [[NSException exceptionWithName:@"DBException" reason:faultString userInfo:nil] raise];
  }
  
  loginResult = [resultDict objectForKey:@"GWSCoderParameters"];
  NSLog(@"coder parameters is %@", loginResult);
  
  enumerator = [loginResult keyEnumerator];
  while ((key = [enumerator nextObject]))
  {
    NSLog(@"%@ - %@", key, [loginResult objectForKey:key]); 
  }
  
  
  NSLog(@"loginResult is %d big", [loginResult count]);

  loginResult2 = [loginResult objectForKey:@"result"];
  NSLog(@"result in login dict is %@", loginResult2);
  
  enumerator = [loginResult2 keyEnumerator];
  while ((key = [enumerator nextObject]))
  {
    NSLog(@"%@ - %@", key, [loginResult2 objectForKey:key]); 
  }
    
  sessionId = [loginResult2 objectForKey:@"sessionId"];
  serverUrl = [loginResult2 objectForKey:@"serverUrl"];
  
  passwordExpired = NO;
  if ([[loginResult2 objectForKey:@"serverUrl"] isEqualToString:@"true"])
      passwordExpired = YES;
  
  userInfoResult = [loginResult2 objectForKey:@"userInfo"];
  userInfo = [[NSMutableDictionary dictionaryWithCapacity:5] retain];
  [userInfo setValue:[userInfoResult objectForKey:@"organizationId"] forKey:@"organizationId"];
  [userInfo setValue:[userInfoResult objectForKey:@"organizationName"] forKey:@"organizationName"];
  [userInfo setValue:[userInfoResult objectForKey:@"profileId"] forKey:@"profileId"];
  [userInfo setValue:[userInfoResult objectForKey:@"roleId"] forKey:@"roleId"];
  [userInfo setValue:[userInfoResult objectForKey:@"userId"] forKey:@"userId"];
  [userInfo setValue:[userInfoResult objectForKey:@"userEmail"] forKey:@"userEmail"];
  [userInfo setValue:[userInfoResult objectForKey:@"userFullName"] forKey:@"userFullName"];
  [userInfo setValue:[userInfoResult objectForKey:@"userName"] forKey:@"userName"];
  

  /* since Salesforce seems to be stubborn and returns an https connection
     even if we initiate a non-secure one, we force it to http */
  if ([[serverUrl substringToIndex:5] isEqualToString:@"https"])
  {
    NSLog(@"we have https....");
      serverUrl = [@"http" stringByAppendingString:[serverUrl substringFromIndex:5]];
  }
  
  [coder release];
  
  if (sessionId == nil)
  {
    [[NSException exceptionWithName:@"DBException" reason:@"No Session information returned." userInfo:nil] raise];
  }
  {
    NSLog(@"sessionId: %@", sessionId);
    NSLog(@"serverUrl: %@", serverUrl);
  }
  
  [service setURL:serverUrl];
}

- (void)query :(NSString *)queryString toWriter:(DBCVSWriter *)writer
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *doneStr;
  BOOL                  done;
  NSString              *queryLocator;
  NSArray               *records;
  NSDictionary          *record;
  NSDictionary          *queryFault;
  NSString              *sizeStr;
  int                   size;

  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  /* prepare the parameters */
  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  [queryParmDict setObject: queryString forKey: @"queryString"];
  
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"query"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];

  
  /* make the query */  
  resultDict = [service invokeMethod: @"query"
                parameters : parmsDict
		order : nil
		timeout : 90];

  NSLog(@"dict is %d big", [resultDict count]);

  enumerator = [resultDict keyEnumerator];
  NSLog(@"before cleaning");
  while ((key = [enumerator nextObject]))
  {
    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
  }
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSDictionary *fault;
      NSDictionary *faultDetail;

      faultDetail = [queryFault objectForKey:@"detail"];
      fault = [faultDetail objectForKey:@"fault"];
      NSLog(@"fault: %@", fault);
      NSLog(@"exception code: %@", [fault objectForKey:@"exceptionCode"]);
      NSLog(@"exception code: %@", [fault objectForKey:@"exceptionMessage"]);
    }

  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];
//  NSLog(@"result: %@", result);

  doneStr = [result objectForKey:@"done"];
  queryLocator = [result objectForKey:@"queryLocator"];
  records = [result objectForKey:@"records"];
  sizeStr = [result objectForKey:@"size"];
 
  if (doneStr != nil)
    {
      NSLog(@"done: %@", doneStr);
      done = NO;
      if ([doneStr isEqualToString:@"true"])
        done = YES;
      else if ([doneStr isEqualToString:@"false"])
        done = NO;
      else
        NSLog(@"Done, unexpected value: %@", doneStr);
    }
  else
    {
      NSLog(@"error, doneStr is nil: unexpected");
      return;
    }

  if (sizeStr != nil)
    {
      int            i;
      int            j;
      int    batchSize;
      NSMutableArray *keys;
      NSMutableArray *set;
      
      
      size = [sizeStr intValue];
      NSLog(@"Declared size is: %d", size);
      
      /* if we have only one element, put it in an array */
      if (size == 1)
        {
          records = [NSArray arrayWithObject:records];
          batchSize = 1;
        }
      record = [records objectAtIndex:0];
      batchSize = [records count];        
      
      NSLog(@"records size is: %d", batchSize);
      
      /* let's get the fields from the keys of the first record */
      keys = [NSMutableArray arrayWithArray:[record allKeys]];
      [keys removeObject:@"GWSCoderOrder"];

      /* remove some fields which get added automatically by salesforce even if not asked for */
      [keys removeObject:@"type"];
      
      /* remove Id only if it is null, else an array of two populated Id is returned by SF */
      if (![[record objectForKey:@"Id"] isKindOfClass: [NSArray class]])
          [keys removeObject:@"Id"];


      NSLog(@"keys: %@", keys);
      
      [writer setFieldNames:[NSArray arrayWithArray:keys] andWriteIt:YES];
      
      set = [[NSMutableArray alloc] init];
      
      /* now cycle all the records and read out the fields */
      for (i = 0; i < batchSize; i++)
        {
          NSMutableArray *values;
	  
          record = [records objectAtIndex:i];
          values = [NSMutableArray arrayWithCapacity:[keys count]];
          for (j = 0; j < [keys count]; j++)
            {
              id       obj;
              id       value;
              NSString *key;
              
              key = [keys objectAtIndex:j];
              obj = [record objectForKey: key];
              if ([key isEqualToString:@"Id"])
                  value = [(NSArray *)obj objectAtIndex: 0];
              else
                  value = obj;
              [values addObject:value];
            }
//          NSLog(@"%d: %@", i, values);
          [set addObject:values];
        }
      [writer writeDataSet:set];
    }
  if (!done)
    {
      NSLog(@"should do query more, queryLocator: %@", queryLocator);
      [self queryMore :queryLocator toWriter:writer];
    }
}

- (void)queryMore :(NSString *)queryLocator toWriter:(DBCVSWriter *)writer
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *doneStr;
  BOOL                  done;
  NSString              *nextQueryLocator;
  NSArray               *records;
  NSDictionary          *record;
  NSString              *sizeStr;
  int                   size;

  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  /* prepare the parameters */
  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  [queryParmDict setObject: queryLocator forKey: @"queryLocator"];
  
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"queryMore"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];

  
  /* make the query */  
  resultDict = [service invokeMethod: @"queryMore"
                parameters : parmsDict
                order : nil
              timeout : 90];

  NSLog(@"dict is %d big", [resultDict count]);

  enumerator = [resultDict keyEnumerator];
  while ((key = [enumerator nextObject]))
  {
    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
  }
  
  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];

  doneStr = [result objectForKey:@"done"];
  nextQueryLocator = [result objectForKey:@"queryLocator"];
  records = [result objectForKey:@"records"];
  sizeStr = [result objectForKey:@"size"];
 
  if (doneStr != nil)
    {
      NSLog(@"done: %@", doneStr);
      done = NO;
      if ([doneStr isEqualToString:@"true"])
        done = YES;
      else if ([doneStr isEqualToString:@"false"])
        done = NO;
      else
        NSLog(@"Done, unexpected value: %@", doneStr);
    }
  else
    {
      NSLog(@"error, doneStr is nil: unexpected");
      return;
    }

  if (sizeStr != nil)
    {
      int            i;
      int            j;
      int    batchSize;
      NSMutableArray *keys;
      NSMutableArray *set;
      
      
      size = [sizeStr intValue];
      NSLog(@"Declared size is: %d", size);
      
      /* if we have only one element, put it in an array */
      if (size == 1)
        {
          records = [NSArray arrayWithObject:records];
          batchSize = 1;
        }
      record = [records objectAtIndex:0];
      batchSize = [records count];        
      
      NSLog(@"records size is: %d", batchSize);
      
      /* let's get the fields from the keys of the first record */
      keys = [NSMutableArray arrayWithArray:[record allKeys]];
      [keys removeObject:@"GWSCoderOrder"];

      /* remove some fields which get added automatically by salesforce even if not asked for */
      [keys removeObject:@"type"];
      
      /* remove Id only if it is null, else an array of two populated Id is returned by SF */
      if (![[record objectForKey:@"Id"] isKindOfClass: [NSArray class]])
        [keys removeObject:@"Id"];
      
      NSLog(@"keys: %@", keys);
      

      set = [[NSMutableArray alloc] init];
      
      /* now cycle all the records and read out the fields */
      for (i = 0; i < batchSize; i++)
        {
          NSMutableArray *values;
	  
          record = [records objectAtIndex:i];
          values = [NSMutableArray arrayWithCapacity:[keys count]];
          for (j = 0; j < [keys count]; j++)
          {
              id       obj;
              id       value;
              NSString *key;
              
              key = [keys objectAtIndex:j];
              obj = [record objectForKey: key];
              if ([key isEqualToString:@"Id"])
                  value = [(NSArray *)obj objectAtIndex: 0];
              else
                  value = obj;
              [values addObject:value];
          }
//          NSLog(@"%d: %@", i, values);
          [set addObject:values];
        }
      [writer writeDataSet:set];
    }
  if (!done)
    {
      NSLog(@"should do query more, nextQueryLocator: %@", nextQueryLocator);
      [self queryMore :nextQueryLocator toWriter:writer];
    }

}

- (void)create :(NSString *)objectName fromReader:(DBCVSReader *)reader
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *doneStr;
  NSArray               *records;
  NSDictionary          *record;
  NSDictionary          *queryFault;
  NSString              *sizeStr;
  int                   size;
  NSMutableDictionary   *objectsDict;
  NSArray               *objectsArray;
  NSArray               *fieldValues;
  NSArray               *fieldNames;
  int                   fieldCount;
  NSMutableArray        *queryObjectsArray;
  NSMutableDictionary   *queryObjectsDict;

  /* retrieve objects to create */
  
  /* first the fields */
  fieldNames = [reader fieldNames];
  fieldCount = [fieldNames count];
  objectsDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  objectsArray = [reader readDataSet];
  
  
  
  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  /* prepare the parameters */
  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  
  NSLog(@"objectsArray: %@", objectsArray);
  queryObjectsArray = [NSMutableArray arrayWithCapacity: [objectsArray count]]; /* maybe a static array could be used here */
  
  enumerator = [objectsArray objectEnumerator];
  while ((fieldValues = [enumerator nextObject]))
  {
    unsigned int i;
    NSMutableDictionary *sObj;
    NSMutableDictionary *sObjType;
    NSMutableArray      *sObjKeyOrder;
    
    sObj = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObj setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    sObjKeyOrder = [NSMutableArray arrayWithCapacity: 2];

    /* each objects needs its type specifier which has its own namespace */
    sObjType = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObjType setObject: @"urn:sobject.partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    [sObjType setObject: objectName forKey:GWSSOAPValueKey];
    [sObj setObject: sObjType forKey:@"type"];
    [sObjKeyOrder addObject:@"type"];

    for (i = 0; i < fieldCount; i++)
      {
        NSLog(@"%@: %@ - %@", objectName, [fieldNames objectAtIndex:i], [fieldValues objectAtIndex:i]);
        [sObj setObject: [fieldValues objectAtIndex:i] forKey: [fieldNames objectAtIndex:i]];
        [sObjKeyOrder addObject:[fieldNames objectAtIndex:i]];
      }
    [sObj setObject: sObjKeyOrder forKey: GWSOrderKey];
    [queryObjectsArray addObject: sObj];
  }


  queryObjectsDict = [NSDictionary dictionaryWithObjectsAndKeys: queryObjectsArray, GWSSOAPValueKey, nil];

  [queryParmDict setObject: queryObjectsDict forKey: @"sObjects"];
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"create"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];

  
  /* make the query */  
  resultDict = [service invokeMethod: @"create"
                parameters : parmsDict
		order : nil
		timeout : 90];
  
  NSLog(@"request: %@", [[NSString alloc] initWithData:
    	[resultDict objectForKey:@"GWSCoderRequestData"] encoding: NSUTF8StringEncoding]);
  

  NSLog(@"dict is %d big", [resultDict count]);

  enumerator = [resultDict keyEnumerator];
  while ((key = [enumerator nextObject]))
  {
    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
  }
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSString *faultCode;
      NSString *faultString;


      faultCode = [queryFault objectForKey:@"faultcode"];
      faultString = [queryFault objectForKey:@"faultstring"];
      NSLog(@"fault code: %@", faultCode);
      NSLog(@"fault String: %@", faultString);
      [[NSException exceptionWithName:@"DBException" reason:faultString userInfo:nil] raise];
    }

  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];
  NSLog(@"result: %@", result);

  doneStr = [result objectForKey:@"done"];
  records = [result objectForKey:@"records"];
  sizeStr = [result objectForKey:@"size"];
 


  if (sizeStr != nil)
    {
      int            i;
      int            j;
      int    batchSize;
      NSMutableArray *keys;
      NSMutableArray *set;
      
      
      size = [sizeStr intValue];
      batchSize = [records count];
      NSLog(@"Declared size is: %d", size);
      NSLog(@"records size is: %d", batchSize);
      
      /* let's get the fields from the keys of the first record */
      record = [records objectAtIndex:0];
      keys = [NSMutableArray arrayWithArray:[record allKeys]];
      [keys removeObject:@"GWSCoderOrder"];

      NSLog(@"keys: %@", keys);
      
      set = [[NSMutableArray alloc] init];
      
      /* now cycle all the records and read out the fields */
      for (i = 0; i < batchSize; i++)
        {
          NSMutableArray *values;
	  
          record = [records objectAtIndex:i];
          values = [NSMutableArray arrayWithCapacity:[keys count]];
          for (j = 0; j < [keys count]; j++)
            {
              NSString *value;
	      
              value = [record objectForKey:[keys objectAtIndex:j]];
              [values addObject:value];
            }
          NSLog(@"%d: %@", i, values);
          [set addObject:values];
        }
    }
}

- (void)update :(NSString *)objectName fromReader:(DBCVSReader *)reader
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *doneStr;
  NSArray               *records;
  NSDictionary          *record;
  NSDictionary          *queryFault;
  NSString              *sizeStr;
  int                   size;
  NSMutableDictionary   *objectsDict;
  NSArray               *objectsArray;
  NSArray               *fieldValues;
  NSArray               *fieldNames;
  int                   fieldCount;
  NSMutableArray        *queryObjectsArray;
  NSMutableDictionary   *queryObjectsDict;
  
  /* retrieve objects to create */
  
  /* first the fields */
  fieldNames = [reader fieldNames];
  fieldCount = [fieldNames count];
  objectsDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  objectsArray = [reader readDataSet];
  
  
  
  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  
  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  /* prepare the parameters */
  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  
  NSLog(@"objectsArray: %@", objectsArray);
  queryObjectsArray = [NSMutableArray arrayWithCapacity: [objectsArray count]]; /* maybe a static array could be used here */
  
  enumerator = [objectsArray objectEnumerator];
  while ((fieldValues = [enumerator nextObject]))
    {
    unsigned int i;
    NSMutableDictionary *sObj;
    NSMutableDictionary *sObjType;
    NSMutableArray      *sObjKeyOrder;
    
    sObj = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObj setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    sObjKeyOrder = [NSMutableArray arrayWithCapacity: 2];
    
    /* each objects needs its type specifier which has its own namespace */
    sObjType = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObjType setObject: @"urn:sobject.partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    [sObjType setObject: objectName forKey:GWSSOAPValueKey];
    [sObj setObject: sObjType forKey:@"type"];
    [sObjKeyOrder addObject:@"type"];
    
    for (i = 0; i < fieldCount; i++)
      {
      NSLog(@"%@: %@ - %@", objectName, [fieldNames objectAtIndex:i], [fieldValues objectAtIndex:i]);
      [sObj setObject: [fieldValues objectAtIndex:i] forKey: [fieldNames objectAtIndex:i]];
      [sObjKeyOrder addObject:[fieldNames objectAtIndex:i]];
      }
    [sObj setObject: sObjKeyOrder forKey: GWSOrderKey];
    [queryObjectsArray addObject: sObj];
    }
  
  
  queryObjectsDict = [NSDictionary dictionaryWithObjectsAndKeys: queryObjectsArray, GWSSOAPValueKey, nil];
  
  [queryParmDict setObject: queryObjectsDict forKey: @"sObjects"];
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"update"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];
  
  
  /* make the query */  
  resultDict = [service invokeMethod: @"update"
                         parameters : parmsDict
                              order : nil
                            timeout : 90];
  
  NSLog(@"request: %@", [[NSString alloc] initWithData:
    	[resultDict objectForKey:@"GWSCoderRequestData"] encoding: NSUTF8StringEncoding]);
  
  
  NSLog(@"dict is %d big", [resultDict count]);
  
  enumerator = [resultDict keyEnumerator];
  while ((key = [enumerator nextObject]))
    {
    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
    }
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
    NSString *faultCode;
    NSString *faultString;
    
    
    faultCode = [queryFault objectForKey:@"faultcode"];
    faultString = [queryFault objectForKey:@"faultstring"];
    NSLog(@"fault code: %@", faultCode);
    NSLog(@"fault String: %@", faultString);
    [[NSException exceptionWithName:@"DBException" reason:faultString userInfo:nil] raise];
    }
  
  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];
  NSLog(@"result: %@", result);
  
  doneStr = [result objectForKey:@"done"];
  records = [result objectForKey:@"records"];
  sizeStr = [result objectForKey:@"size"];
  
  
  
  if (sizeStr != nil)
    {
    int            i;
    int            j;
    int    batchSize;
    NSMutableArray *keys;
    NSMutableArray *set;
    
    
    size = [sizeStr intValue];
    batchSize = [records count];
    NSLog(@"Declared size is: %d", size);
    NSLog(@"records size is: %d", batchSize);
    
    /* let's get the fields from the keys of the first record */
    record = [records objectAtIndex:0];
    keys = [NSMutableArray arrayWithArray:[record allKeys]];
    [keys removeObject:@"GWSCoderOrder"];
    
    NSLog(@"keys: %@", keys);
    
    set = [[NSMutableArray alloc] init];
    
    /* now cycle all the records and read out the fields */
    for (i = 0; i < batchSize; i++)
      {
      NSMutableArray *values;
      
      record = [records objectAtIndex:i];
      values = [NSMutableArray arrayWithCapacity:[keys count]];
      for (j = 0; j < [keys count]; j++)
        {
        NSString *value;
        
        value = [record objectForKey:[keys objectAtIndex:j]];
        [values addObject:value];
        }
      NSLog(@"%d: %@", i, values);
      [set addObject:values];
      }
    }
}


- (NSArray *)describeGlobal
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *encoding;
  NSDictionary          *queryFault;
  NSString              *maxBatchSizeStr;
  NSArray               *types;

  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  /* prepare the parameters */
  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"describeGlobal"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];

  
  /* make the query */  
  resultDict = [service invokeMethod: @"describeGlobal"
                parameters : parmsDict
		order : nil
		timeout : 90];


  NSLog(@"dict is %d big", [resultDict count]);
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSDictionary *fault;
      NSDictionary *faultDetail;

      faultDetail = [queryFault objectForKey:@"detail"];
      fault = [faultDetail objectForKey:@"fault"];
      NSLog(@"fault: %@", fault);
      NSLog(@"exception code: %@", [fault objectForKey:@"exceptionCode"]);
      NSLog(@"exception message: %@", [fault objectForKey:@"exceptionMessage"]);
      [[NSException exceptionWithName:@"DBException" reason:[fault objectForKey:@"exceptionMessage"] userInfo:nil] raise];
    }

  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];
  NSLog(@"result: %@", result);

  encoding = [result objectForKey:@"encoding"];
  maxBatchSizeStr = [result objectForKey:@"maxBatchSize"];
  types = [result objectForKey:@"types"];

  return types;
}

- (void)describeSObject: (NSString *)objectType toWriter:(DBCVSWriter *)writer

{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSDictionary          *queryFault;
  NSArray               *records;
  NSDictionary          *record;
  int                   i;
  int                   size;
  NSMutableArray        *keys;
  NSMutableArray        *set;


  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  /* prepare the parameters */
  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

//  queryObjectsDict = [NSDictionary dictionaryWithObjectsAndKeys: objectIdArray, GWSSOAPValueKey, nil];

  [queryParmDict setObject: objectType forKey: @"sObjectType"];

  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"describeSObject"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];
  
  /* make the query */  
  resultDict = [service invokeMethod: @"describeSObject"
                parameters : parmsDict
		order : nil
		timeout : 90];


  NSLog(@"dict is %d big", [resultDict count]);
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSDictionary *fault;
      NSDictionary *faultDetail;

      faultDetail = [queryFault objectForKey:@"detail"];
      fault = [faultDetail objectForKey:@"fault"];
      NSLog(@"fault: %@", fault);
      NSLog(@"exception code: %@", [fault objectForKey:@"exceptionCode"]);
      NSLog(@"exception message: %@", [fault objectForKey:@"exceptionMessage"]);
      [[NSException exceptionWithName:@"DBException" reason:[fault objectForKey:@"exceptionMessage"] userInfo:nil] raise];
    }

  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];

  records = [result objectForKey:@"fields"];
  size = [records count];

  /* if we have only one element, put it in an array */
  if (size == 1)
    {
      records = [NSArray arrayWithObject:records];
    }
  record = [records objectAtIndex:0];    
 

  keys = [NSMutableArray arrayWithArray:[record allKeys]];
  [keys removeObject:@"GWSCoderOrder"];
  //  NSLog(@"keys: %@", keys);

  [writer setFieldNames:[NSArray arrayWithArray:keys] andWriteIt:YES];
      
  set = [[NSMutableArray alloc] init];

  for (i = 0; i < size; i++)
    {
      NSMutableArray *values;
      int j;
	  
      record = [records objectAtIndex:i];

      values = [NSMutableArray arrayWithCapacity:[keys count]];
      for (j = 0; j < [keys count]; j++)
	{
	  id       obj;
	  id       value;
	  NSString *key;
              
	  key = [keys objectAtIndex:j];
	  obj = [record objectForKey: key];

	  value = obj;
	  [values addObject:value];
	}
      //      NSLog(@"%d: %@", i, values);
      [set addObject:values];
    }
  [writer writeDataSet:set];
}


- (NSMutableArray *)delete :(NSArray *)objectIdArray
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSString              *key;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *doneStr;
  NSArray               *records;
  NSDictionary          *record;
  NSDictionary          *queryFault;
  NSString              *sizeStr;
  int                   size;
  NSMutableArray        *queryObjectsDict;
  NSString              *errorStr;
  NSMutableArray        *resultArray;
  
  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  /* prepare the parameters */
  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
  
  queryObjectsDict = [NSDictionary dictionaryWithObjectsAndKeys: objectIdArray, GWSSOAPValueKey, nil];

  [queryParmDict setObject: queryObjectsDict forKey: @"ids"];
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"delete"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];

  
  /* make the query */  
  resultDict = [service invokeMethod: @"delete"
                parameters : parmsDict
		order : nil
		timeout : 90];
  
  NSLog(@"request: %@", [[NSString alloc] initWithData:
    	[resultDict objectForKey:@"GWSCoderRequestData"] encoding: NSUTF8StringEncoding]);
  

  NSLog(@"dict is %d big", [resultDict count]);

  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSString *faultCode;
      NSString *faultString;

      faultCode = [queryFault objectForKey:@"faultcode"];
      faultString = [queryFault objectForKey:@"faultstring"];
      NSLog(@"fault code: %@", faultCode);
      NSLog(@"fault String: %@", faultString);
      [[NSException exceptionWithName:@"DBException" reason:faultString userInfo:nil] raise];
    }
  
  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];
  NSLog(@"result: %@", result);
  
  resultArray = nil;

  if (result != nil)
    {
      NSMutableArray *keys;
      id resultRow;
      NSEnumerator   *objEnu;
      NSDictionary   *rowDict;

      /* if only one element gets returned, GWS can't interpret it as an array */
      if (!([result isKindOfClass: [NSArray class]]))
         result = [NSArray arrayWithObject: result];
         
      resultArray = [[NSMutableArray arrayWithCapacity:1] retain];
      objEnu = [result objectEnumerator];
      while ((resultRow = [objEnu nextObject]))
        {
          id message;
          id success;
          id errors;
          id statusCode;
          id sfId;

          errors = [resultRow objectForKey:@"errors"];
          message  = [errors objectForKey:@"message"];          
          statusCode = [errors objectForKey:@"statusCode"]; 
          success = [resultRow objectForKey:@"success"];
          sfId = [resultRow objectForKey:@"id"];

          NSLog(@"resultRow: %@", resultRow);
          NSLog(@"errors: %@", errors);
          NSLog(@"success: %@", success);
          NSLog(@"message: %@", message);
          NSLog(@"statusCode: %@", statusCode);
          NSLog(@"id: %@", sfId);

          if ([success isEqualToString:@"true"])
            {
              rowDict = [NSDictionary dictionaryWithObjectsAndKeys:
                success, @"success",
                sfId, @"id",
                nil];            
            }
          else
            {
              rowDict = [NSDictionary dictionaryWithObjectsAndKeys:
                success, @"success",
                message, @"message",
                statusCode, @"statusCode",
                nil];
            }
	  [resultArray addObject:rowDict];
	}
  }
  NSLog(@"result array: %@", resultArray);
  return [resultArray autorelease];
}

- (NSMutableArray *)deleteFromReader:(DBCVSReader *)reader
{
  NSMutableArray *objectsArray;
  NSMutableArray *resultArray;

  /* retrieve objects to delete */
  // FIXME perhaps this copy is useless
  objectsArray = [[NSMutableArray arrayWithArray:[reader readDataSet]] retain];
  NSLog(@"objects to delete: %@", objectsArray);
  NSLog(@"count of objects to delete: %d", [objectsArray count]);

  resultArray = [self delete:objectsArray];
  [objectsArray release];
  return resultArray;
}

/* accessors*/
- (NSString *) sessionId
{
  return sessionId;
}

- (NSString *) serverUrl
{
  return serverUrl;
}

- (BOOL) passwordExpired
{
  return passwordExpired;
}

- (NSDictionary *) userInfo
{
  return userInfo;
}

- (void)dealloc
{
  [userInfo release];
  [service release];
  [super dealloc];
}

@end
