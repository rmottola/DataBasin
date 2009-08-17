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
  
  [service setDebug:YES];
  
  
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
  while ((key = [enumerator nextObject]))
  {
    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
  }
  

  NSLog(@"request: %@", [[NSString alloc] initWithData:
    	[resultDict objectForKey:@"GWSCoderRequestData"] encoding: NSUTF8StringEncoding]);
  
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
  
  
  NSLog(@"loginResult2 is %d big", [loginResult2 count]);
  sessionId = [loginResult2 objectForKey:@"sessionId"];
  serverUrl = [loginResult2 objectForKey:@"serverUrl"];
  
  /* since Salesforce seems to be stubborn and returns an https connection
     even if we initiate a non-secure one, we force it to http */
  if ([[serverUrl substringToIndex:6] isEqualToString:@"https"])
  {
      serverUrl = [@"http://" stringByAppendingString:[serverUrl substringFromIndex:6]];
  }
  
  [coder release];
  
  if (sessionId != nil)
  {
    NSLog(@"sessionId: %@", sessionId);
    NSLog(@"serverUrl: %@", serverUrl);
  }
  
  [service setURL:serverUrl];
  [service setDebug:YES];
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
  while ((key = [enumerator nextObject]))
  {
//    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
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
  NSLog(@"result: %@", result);

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
      batchSize = [records count];
      NSLog(@"Declared size is: %d", size);
      NSLog(@"records size is: %d", batchSize);
      
      /* let's get the fields from the keys of the first record */
      record = [records objectAtIndex:0];
      keys = [NSMutableArray arrayWithArray:[record allKeys]];
      [keys removeObject:@"GWSCoderOrder"];

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
	          NSString *value;
	      
	          value = [record objectForKey:[keys objectAtIndex:j]];
	          [values addObject:value];
	        }
	    NSLog(@"%d: %@", i, values);
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
//  NSLog(@"result: %@", result);

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
  BOOL                  done;
  NSString              *queryLocator;
  NSArray               *records;
  NSDictionary          *record;
  NSDictionary          *queryFault;
  NSString              *sizeStr;
  int                   size;
  NSMutableDictionary   *objectsDict;
  NSMutableDictionary   *objectDict;
  NSArray               *objectsArray;
  NSArray               *objectArray;
  NSArray               *fieldValues;
  NSArray               *fieldNames;
  int                   fieldCount;
  NSMutableArray        *queryObjectsArray;


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
    
    sObj = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObj setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    sObjType = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObjType setObject: @"urn:sobject.partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    [sObj setObject: objectName forKey:@"type"];
    for (i = 0; i < fieldCount; i++)
      {
        NSLog(@"%@: %@ - %@", objectName, [fieldNames objectAtIndex:i], [fieldValues objectAtIndex:i]);
        [sObj setObject: [fieldValues objectAtIndex:i] forKey: [fieldNames objectAtIndex:i]];
      }
    [queryObjectsArray addObject: sObj];
  }
  [queryParmDict setObject: queryObjectsArray forKey: @"sObjects"];
  
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
      
//      [writer setFieldNames:[NSArray arrayWithArray:keys] andWriteIt:YES];
      
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
//      [writer writeDataSet:set];
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
  //  [queryParmDict setObject: queryString forKey: @"queryString"];
  
  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"describeGlobal"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];

  
  /* make the query */  
  resultDict = [service invokeMethod: @"describeGlobal"
                parameters : parmsDict
		order : nil
		timeout : 90];

  //  NSLog(@"request: %@", [[NSString alloc] initWithData:
  //    	[resultDict objectForKey:@"GWSCoderRequestData"] encoding: NSUTF8StringEncoding]);

  NSLog(@"dict is %d big", [resultDict count]);

  enumerator = [resultDict keyEnumerator];
  while ((key = [enumerator nextObject]))
  {
//    NSLog(@"%@ - %@", key, [resultDict objectForKey:key]); 
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
  NSLog(@"result: %@", result);

  encoding = [result objectForKey:@"encoding"];
  maxBatchSizeStr = [result objectForKey:@"maxBatchSize"];
  types = [result objectForKey:@"types"];

  return types;
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

- (void)dealloc
{
  NSLog(@"dealloc service");
  [service release];
  [super dealloc];
}

@end
