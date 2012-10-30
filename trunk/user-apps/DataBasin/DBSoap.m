/*
   Project: DataBasin

   Copyright (C) 2008-2012 Free Software Foundation

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
#import "DBSObject.h"
#import "DBCVSWriter.h"
#import "DBCVSReader.h"


@implementation DBSoap

- (void)setLogger: (DBLogger *)l
{
  if (logger)
    [logger release];
  logger = [l retain];
}

- (DBLogger *)logger
{
  return logger;
}

/**<p>executes login</p>
   <p><i>url</i> specifies the URL of the endpoint</p>
   <p><i>useHttps</i> specifies if secure connecton has to be used or not. If not, http is attempted and then enforced.
   The Salesforce.com instance must be configured to accept non-secure connections.</p>
 */
- (void)login :(NSURL *)url :(NSString *)userName :(NSString *)password :(BOOL)useHttps
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
		  nil]];

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

  [logger log: LogDebug: @"[DBSoap Login]:resultDict is %d big\n", [resultDict count]];
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
  {
    NSString *faultCode;
    NSString *faultString;
    
    
    faultCode = [queryFault objectForKey:@"faultcode"];
    faultString = [queryFault objectForKey:@"faultstring"];
    [logger log: LogStandard: @"[DBSoap Login]: fault code: %@\n", faultCode];
    [logger log: LogStandard: @"[DBSoap Login]: fault String: %@\n", faultString];
    [[NSException exceptionWithName:@"DBException" reason:faultString userInfo:nil] raise];
  }
  
  loginResult = [resultDict objectForKey:@"GWSCoderParameters"];
  [logger log: LogDebug: @"[DBSoap Login]: coder parameters is %@\n", loginResult];
  
  enumerator = [loginResult keyEnumerator];
  while ((key = [enumerator nextObject]))
  {
    [logger log: LogDebug: @"[DBSoap Login]:%@ - %@\n", key, [loginResult objectForKey:key]]; 
  }
  
 

  loginResult2 = [loginResult objectForKey:@"result"];
  [logger log: LogDebug: @"[DBSoap Login]: %@\n", loginResult2];
  
  enumerator = [loginResult2 keyEnumerator];
  while ((key = [enumerator nextObject]))
  {
    [logger log: LogDebug: @"[DBSoap Login]:%@ - %@\n", key, [loginResult2 objectForKey:key]]; 
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
    [logger log: LogInformative: @"[DBSoap Login]: preferences set to https....\n"];
    if (!useHttps)
      serverUrl = [@"http" stringByAppendingString:[serverUrl substringFromIndex:5]];
  }
  
  [coder release];
  
  if (sessionId == nil)
  {
    [[NSException exceptionWithName:@"DBException" reason:@"No Session information returned." userInfo:nil] raise];
  }
  else
  {
    [logger log: LogStandard: @"[DBSoap Login]: sessionId: %@\n", sessionId];
    [logger log: LogStandard: @"[DBSoap Login]: serverUrl: %@\n", serverUrl];
  }
  
  [service setURL:serverUrl];}


/** <p>Execute SOQL query <i>queryString</i> and returns the resulting DBSObjects as an array.</p>
  <p>This method will query all resultinng objects of the query, repeatedly querying again if necessary depending on the batch size.</p>
  <p>Returns exception</p>
*/
- (NSMutableArray *)queryFull :(NSString *)queryString queryAll:(BOOL)all
{
  NSString       *qLoc;
  NSMutableArray *sObjects;
  
  sObjects = [[NSMutableArray alloc] init];

  qLoc = [self query: queryString queryAll:all toArray: sObjects];
  [logger log: LogInformative: @"[DBSoap queryFull]: query locator after first query: %@\n", qLoc];
  while (qLoc != nil)
    qLoc = [self queryMore: qLoc toArray: sObjects];
  
  return sObjects;
}


/** <p>execute SOQL query and write the resulting DBSObjects into the <i>objects</i> array
  which must be valid and allocated. </p>
  <p>If the query locator is returned,  a query more has to be executed.</p>
  <p>Returns exception</p>
*/
- (NSString *)query :(NSString *)queryString queryAll:(BOOL)all toArray:(NSMutableArray *)objects
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *doneStr;
  BOOL                  done;
  NSString              *queryLocator;
  NSArray               *records;
  NSDictionary          *record;
  NSDictionary          *queryFault;
  NSDictionary          *coderError;
  NSString              *sizeStr;
  unsigned long         size;
  
  /* if the destination array is nil, exit */
  if (objects == nil)
    return nil;
  
  queryLocator = nil;
 
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
  
  
  /* make the query */  
  if (all)
    {
      [parmsDict setObject: queryParmDict forKey: @"queryAll"];
      [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];
      resultDict = [service invokeMethod: @"queryAll"
			     parameters : parmsDict
				  order : nil
				timeout : 90];
    }
  else
    {
      [parmsDict setObject: queryParmDict forKey: @"query"];
      [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];
      resultDict = [service invokeMethod: @"query"
			     parameters : parmsDict
				  order : nil
				timeout : 90];
    }
  [logger log: LogDebug: @"[DBSoap query] result: %@\n", resultDict];
  coderError = [resultDict objectForKey:@"GWSCoderError"];
  if (coderError != nil)
    {
      [logger log: LogStandard :@"[DBSoap query] error: %@\n", coderError];
      [[NSException exceptionWithName:@"DBException" reason:@"Coder Error, check log" userInfo:nil] raise];
    }
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSDictionary *faultDetail;
      NSString *faultName;
    
      faultDetail = [queryFault objectForKey:@"detail"];
      faultName = [[faultDetail objectForKey:@"GWSCoderOrder"] objectAtIndex: 0];
      if (faultName)
	{
	  NSDictionary *fault;
	  NSString *exceptionMessage;

	  [logger log: LogInformative: @"[DBSoap query] fault name: %@\n", faultName];
	  fault = [faultDetail objectForKey:faultName];
	  exceptionMessage = [fault objectForKey:@"exceptionMessage"];

	  [logger log: LogStandard: @"[DBSoap query] exception code: %@\n", [fault objectForKey:@"exceptionCode"]];
	  [logger log: LogStandard: @"[DBSoap query] exception: %@\n", exceptionMessage];
	  [[NSException exceptionWithName:@"DBException" reason:exceptionMessage userInfo:nil] raise];
	}
      else
	{
	  [logger log: LogInformative: @"[DBSoap query] fault detail: %@\n", faultDetail];
	}
      return nil;
    }
  
  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];
  [logger log: LogDebug: @"[DBSoap query] result: %@\n", result];  
  doneStr = [result objectForKey:@"done"];
  records = [result objectForKey:@"records"];
  sizeStr = [result objectForKey:@"size"];
  
  if (doneStr != nil)
    {
      [logger log: LogDebug: @"[DBSoap query] done: %@\n", doneStr];
      done = NO;
      if ([doneStr isEqualToString:@"true"])
        done = YES;
      else if ([doneStr isEqualToString:@"false"])
        done = NO;
      else
        [logger log: LogStandard: @"[DBSoap query] Done, unexpected value: %@\n", doneStr];
    }
  else
    {
      [logger log: LogStandard: @"[DBSoap query] error, doneStr is nil: unexpected\n"];
      return nil;
    }
  
  if (sizeStr != nil)
    {
      int            i;
      int            j;
      int    batchSize;
      NSMutableArray *keys;
      NSScanner *scan;
      long long ll;

      scan = [NSScanner scannerWithString:sizeStr];
      if ([scan scanLongLong:&ll])
	size = (unsigned long)ll;
      else
	size = 0;
    
      //size = [sizeStr intValue];
      [logger log: LogInformative: @"[DBSoap query] Declared size is: %lu\n", size];
    
      /* if we have only one element, put it in an array */
      if (size == 1)
        {
          records = [NSArray arrayWithObject:records];
        }
      record = [records objectAtIndex:0];
      batchSize = [records count];        
      
      [logger log: LogInformative :@"[DBSoap query] records size is: %d\n", batchSize];
      /* let's get the fields from the keys of the first record */
      keys = [NSMutableArray arrayWithArray:[record allKeys]];
      [keys removeObject:@"GWSCoderOrder"];
      
      /* remove some fields which get added automatically by salesforce even if not asked for */
      [keys removeObject:@"type"];
      
      /* remove Id only if it is null, else an array of two populated Id is returned by SF */
      if (![[record objectForKey:@"Id"] isKindOfClass: [NSArray class]])
        [keys removeObject:@"Id"];
      
      
      /* Count() is not like to aggrecate count(Id) and returns no AggregateResult
	 but returns just a count without an actual records array.
	 Thus we fake one single object. */
      if (batchSize == 0 && size > 0)
	{
	  DBSObject *sObj;
        
          sObj = [[DBSObject alloc] init];
	  [sObj setValue: [NSNumber numberWithUnsignedLong:size] forField: @"count"];
	  [objects addObject:sObj];
	  [sObj release];
	}
      /* now cycle all the records and read out the fields */
      for (i = 0; i < batchSize; i++)
        {
          DBSObject *sObj;
        
          sObj = [[DBSObject alloc] init];
          record = [records objectAtIndex:i];
	  [logger log: LogDebug: @"[DBSoap query] record :%@\n", record];
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
              [sObj setValue: value forField: key];
            }
          [objects addObject:sObj];
          [sObj release];
        }
    }
  if (!done)
    {
      queryLocator = [result objectForKey:@"queryLocator"];
      [logger log: LogDebug: @"[DBSoap query] should do query more, queryLocator: %@\n", queryLocator];
    }
  return queryLocator;
}


/** <p>Execute SOQL query more and write the resulting DBSObjectes into the <i>objects</i> array
    which must be valid and allocated, continuing from the given query locator <i>locator</i>. </p>
    <p>If the query locator is returned,  a query more has to be executed.</p>
*/
- (NSString *)queryMore :(NSString *)locator toArray:(NSMutableArray *)objects
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSString              *doneStr;
  BOOL                  done;
  NSString              *queryLocator;
  NSArray               *records;
  NSDictionary          *record;
  NSDictionary          *queryFault;
  NSString              *sizeStr;
  unsigned long         size;

  /* if the destination array is nil, exit */
  if (objects == nil)
    return nil;

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
  [queryParmDict setObject: locator forKey: @"queryLocator"];  

  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"queryMore"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey]; 
  
  /* make the query */  
  resultDict = [service invokeMethod: @"queryMore"
                         parameters : parmsDict
                              order : nil
                            timeout : 90];
  

  queryLocator = nil;
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

  doneStr = [result objectForKey:@"done"];
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
      return nil;
    }

  if (sizeStr != nil)
    {
      int            i;
      int            j;
      NSUInteger     batchSize;
      NSMutableArray *keys;
      
      /* this will be only as big as a batch anyway */
      size = (unsigned long)[sizeStr intValue];
      NSLog(@"Declared size is: %lu", size);
      
      /* if we have only one element, put it in an array */
      if (size == 1)
        {
          records = [NSArray arrayWithObject:records];
        }
      record = [records objectAtIndex:0];
      batchSize = [records count];        
      
      NSLog(@"records size is: %lu", batchSize);
      
      /* let's get the fields from the keys of the first record */
      keys = [NSMutableArray arrayWithArray:[record allKeys]];
      [keys removeObject:@"GWSCoderOrder"];

      /* remove some fields which get added automatically by salesforce even if not asked for */
      [keys removeObject:@"type"];
      
      /* remove Id only if it is null, else an array of two populated Id is returned by SF */
      if (![[record objectForKey:@"Id"] isKindOfClass: [NSArray class]])
          [keys removeObject:@"Id"];


      NSLog(@"keys: %@", keys);
      
      /* now cycle all the records and read out the fields */
      for (i = 0; i < batchSize; i++)
        {
          DBSObject *sObj;
	  
          sObj = [[DBSObject alloc] init];
          record = [records objectAtIndex:i];
 
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
              [sObj setValue: value forField: key];
            }
          [objects addObject:sObj];
          [sObj release];
        }
    }
  if (!done)
    {
      queryLocator = [result objectForKey:@"queryLocator"];
      [logger log: LogDebug: @"[DBSoap queryMore] should do query more, queryLocator: %@\n", queryLocator];
    }
  return queryLocator;
}

/**
  <p>execute a the given query on the objects given in the fromArray.<br>
  The selection clause is automatically generated to identify the object by the field passed in the array. Only if the field is an unique identifier 
  the result is a single record, else, more records are returned.<br>
  The Where clause is either automatically generated if none is present or, if Where is already present, it is appended with an AND operator</p>
  <p>the parameter <em>withBatchSize</em> selects the querying behaviour:
  <ul>
  <li>&lgt; 0:Auto-sizing of the batch, the maximum query size is formed</li>
  <li>0, 1: A single element is queried with, making the clause Field = 'value'</li>
  <li>&gt 1: The given batch size is used in a clause like Field in ('value1', 'value2', ... )</li>
  </ul>
 */
- (void)queryIdentify :(NSString *)queryString with: (NSString *)identifier queryAll:(BOOL)all fromArray:(NSArray *)fromArray toArray:(NSMutableArray *)outArray withBatchSize:(int)batchSize
{
  unsigned i;
  unsigned j;
  unsigned b;
  BOOL batchable;
  BOOL autoBatch;
  
  batchable = NO;
  autoBatch = NO;
  if (batchSize < 0)
    {
      autoBatch = YES;
      batchable = YES;
    }
   else if (batchSize > 1)
     batchable = YES;
      
  i = 0;
  while (i < [fromArray count])
    {
      NSMutableString *completeQuery;
      NSMutableArray *resArray;

      [logger log: LogDebug: @"[DBSoap queryIdentify] %u %@\n", i, [fromArray objectAtIndex: i]];

      completeQuery = [[NSMutableString stringWithString: queryString] retain];
      if ([queryString rangeOfString:@"WHERE" options:NSCaseInsensitiveSearch].location != NSNotFound)
	{
	  [completeQuery appendString: @" AND "];
	}
      else
	{
	  [completeQuery appendString: @" WHERE "];
	}
      [completeQuery appendString: identifier];
      if (!batchable)
	{
	  [completeQuery appendString: @" = '"];
	  [completeQuery appendString: [fromArray objectAtIndex: i]];
	  [completeQuery appendString: @"'"];
	  i++;
	}
      else
	{
	  b = 0;
	  [completeQuery appendString: @" in ("];
	  /* we always stay inside the maximum soql query size and if we have a batch limit we cap on that */
	  while (((i < [fromArray count]) && ([completeQuery length] < MAX_SOQL_SIZE-20)) && (autoBatch || (b < batchSize)))
	    {
	      [completeQuery appendString: @"'"];
	      [completeQuery appendString: [fromArray objectAtIndex: i]];
	      [completeQuery appendString: @"',"];
	      i++;
	      b++;
	    }
	  if (b > 0)
	    [completeQuery deleteCharactersInRange: NSMakeRange([completeQuery length]-1, 1)];
	  [completeQuery appendString: @")"];
	}
      [logger log: LogDebug: @"[DBSoap queryIdentify] query: %@\n", completeQuery];

      /* since we might get back more records for each object to identify, we need to use query more */
      resArray = [self queryFull:completeQuery queryAll:all];
 
      for (j = 0; j < [resArray count]; j++)
	[outArray addObject: [resArray objectAtIndex: j]];
      [completeQuery release];
    }
}

/**
  insert an array of DBSObjects.<br>
  The objects in the array shall all be of the same type.
 */
- (void)create :(NSString *)objectName fromArray:(NSMutableArray *)objects
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSDictionary          *queryResult;
  NSArray               *fieldNames;
  int                   fieldCount;
  NSMutableArray        *queryObjectsArray;
  DBSObject             *sObject;
  unsigned              batchCounter;

  if ([objects count] == 0)
    return;
  
  upBatchSize = 1; // FIXME ########
  
  /* prepare the header */
  sessionHeaderDict = [[NSMutableDictionary dictionaryWithCapacity: 2] retain];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [[NSMutableDictionary dictionaryWithCapacity: 2] retain];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
    
  enumerator = [objects objectEnumerator];
  batchCounter = 0;
  queryObjectsArray = [[NSMutableArray arrayWithCapacity: upBatchSize] retain];
  while ((sObject = [enumerator nextObject]))
  {
    unsigned            i;
    NSMutableDictionary *sObj;
    NSMutableDictionary *sObjType;
    NSMutableArray      *sObjKeyOrder;
    NSMutableDictionary *queryObjectsDict;
    NSMutableDictionary *parmsDict;
    NSMutableDictionary *queryParmDict;
    NSDictionary        *result;
    NSArray             *records;
    NSDictionary        *record;
    NSDictionary        *queryFault;
    NSString            *sizeStr;
    int                 size;

    
    
    NSLog(@"inner cycle: %d", batchCounter);
    sObj = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObj setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    sObjKeyOrder = [NSMutableArray arrayWithCapacity: 2];

    /* each objects needs its type specifier which has its own namespace */
    sObjType = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObjType setObject: @"urn:sobject.partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    [sObjType setObject: objectName forKey:GWSSOAPValueKey];
    [sObj setObject: sObjType forKey:@"type"];
    [sObjKeyOrder addObject:@"type"];

    fieldNames = [sObject fieldNames];
    fieldCount = [fieldNames count];

    for (i = 0; i < fieldCount; i++)
      {
	NSString *keyName;

	keyName = [fieldNames objectAtIndex:i];
        [sObj setObject: [sObject fieldValue:keyName] forKey:keyName];
        [sObjKeyOrder addObject:keyName];
      }
    [sObj setObject: sObjKeyOrder forKey: GWSOrderKey];
    [queryObjectsArray addObject: sObj];

    if (batchCounter == upBatchSize-1)
      {
	/* prepare the parameters */
	queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
	[queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
	
	[logger log: LogDebug: @"[DBSoap create] create objects array: %@\n", objects];

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
  
  

	NSLog(@"create result dict is %d big", [resultDict count]);
  
	queryFault = [resultDict objectForKey:@"GWSCoderFault"];
	if (queryFault != nil)
	  {
	    NSString *faultCode;
	    NSString *faultString;


	    faultCode = [queryFault objectForKey:@"faultcode"];
	    faultString = [queryFault objectForKey:@"faultstring"];
	    [logger log: LogStandard: @"[DBSoap create] fault code: %@\n", faultCode];
	    [logger log: LogStandard: @"[DBSoap create] fault String: %@\n", faultString];
	    [[NSException exceptionWithName:@"DBException" reason:faultString userInfo:nil] raise];
	  }

	queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
	result = [queryResult objectForKey:@"result"];
	[logger log: LogDebug: @"[DBSoap create] result: %@\n", result];

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
	    /* we don't do yet anything useful with the results... */
	    [set release];
	  }
	[logger log: LogDebug: @"[DBSoap create] reiniting cycle...\n"];
	[queryObjectsArray removeAllObjects];
	batchCounter = 0;
      }
    else /* of batch */
      {
	batchCounter++;
      }
  }
  [logger log: LogDebug: @"[DBSoap create] Outer cycle ended\n"];
  [queryObjectsArray release];
  [sessionHeaderDict release];
  [headerDict release];
}


/**
  <p>Update an array of DBSObjects.<br>
  The objects in the array shall all be of the same type.
  </p>
  <p>The batch size sent is determined by the upBatchSize property of the class</p>
 */
- (void)update :(NSString *)objectName fromArray:(NSMutableArray *)objects
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSDictionary          *resultDict;
  NSEnumerator          *enumerator;
  NSArray               *fieldNames;
  unsigned              fieldCount;
  DBSObject             *sObject;
  unsigned              batchCounter;
  NSMutableArray        *queryObjectsArray;

  if ([objects count] == 0)
    return;
  
  upBatchSize = 1; // FIXME ########

  /* prepare the header */
  sessionHeaderDict = [[NSMutableDictionary dictionaryWithCapacity: 2] retain];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [[NSMutableDictionary dictionaryWithCapacity: 2] retain];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];
  
  [logger log: LogDebug: @"[DBSoap update] update objects array: %@\n", objects];
  
  
  enumerator = [objects objectEnumerator];
  batchCounter = 0;
  queryObjectsArray = [[NSMutableArray arrayWithCapacity: upBatchSize] retain];
  while ((sObject = [enumerator nextObject]))
  {
    unsigned int i;
    NSMutableDictionary *sObj;
    NSMutableDictionary *sObjType;
    NSMutableArray      *sObjKeyOrder;
    NSMutableDictionary *queryObjectsDict;
    NSMutableDictionary *parmsDict;
    NSMutableDictionary *queryParmDict;
    NSDictionary        *queryResult;
    NSDictionary        *result;
    NSArray             *records;
    NSDictionary        *record;
    NSDictionary        *queryFault;
    NSString            *sizeStr;
    unsigned            size;

    NSLog(@"inner cycle: %d", batchCounter);
    sObj = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObj setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    sObjKeyOrder = [NSMutableArray arrayWithCapacity: 2];

    /* each objects needs its type specifier which has its own namespace */
    sObjType = [NSMutableDictionary dictionaryWithCapacity: 2];
    [sObjType setObject: @"urn:sobject.partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
    [sObjType setObject: objectName forKey:GWSSOAPValueKey];
    [sObj setObject: sObjType forKey:@"type"];
    [sObjKeyOrder addObject:@"type"];

    fieldNames = [sObject fieldNames];
    fieldCount = [fieldNames count];

    for (i = 0; i < fieldCount; i++)
      {
	NSString *keyName;

	keyName = [fieldNames objectAtIndex:i];
	[sObj setObject: [sObject fieldValue:keyName] forKey:keyName];
	[sObjKeyOrder addObject:keyName];
      }
    [sObj setObject: sObjKeyOrder forKey: GWSOrderKey];
    [queryObjectsArray addObject: sObj];

    if (batchCounter == upBatchSize-1)
      {
	/* prepare the parameters */
	queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
	[queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

	NSLog(@"queryObjectsArray count: %d of batchCounter %d", [queryObjectsArray count], batchCounter);

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
  
	NSLog(@"update result dict is %d big", [resultDict count]);
  
	queryFault = [resultDict objectForKey:@"GWSCoderFault"];
	if (queryFault != nil)
	  {
	    NSString *faultCode;
	    NSString *faultString;
	    

	    faultCode = [queryFault objectForKey:@"faultcode"];
	    faultString = [queryFault objectForKey:@"faultstring"];
	    [logger log: LogStandard: @"[DBSoap update] fault code: %@\n", faultCode];
	    [logger log: LogStandard: @"[DBSoap update] fault String: %@\n", faultString];
	    [[NSException exceptionWithName:@"DBException" reason:faultString userInfo:nil] raise];
	  }


	queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
	result = [queryResult objectForKey:@"result"];
	NSLog(@"result: %@", result);
#if 0
	records = [result objectForKey:@"records"];
	sizeStr = [result objectForKey:@"size"];
 

	if (sizeStr != nil)
	  {
	    unsigned        i;
	    unsigned        j;
	    unsigned        batchSize;
	    NSMutableArray *keys;
	    NSMutableArray *set;
      
      
	    size = (unsigned)[sizeStr intValue];
	    batchSize = [records count];
	    NSLog(@"Declared size is: %u", size);
	    NSLog(@"records size is: %u", batchSize);
      
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
		NSLog(@"%u: %@", i, values);
		[set addObject:values];
	      }
	    /* we don't do yet anything useful with the results... */
	    [set release];
	  }
#endif
	NSLog(@"reiniting cycle...");
	[queryObjectsArray removeAllObjects];
	batchCounter = 0;
      }
    else /* of batch */
      {
	batchCounter++;
      }
    NSLog(@"outer cycle....");
  } /* while: outer global object enumerator cycle */
  [logger log: LogDebug: @"[DBSoap update] outer cycle ended %@\n", sObject];

  [queryObjectsArray release];
  [sessionHeaderDict release];
  [headerDict release];
}




/** runs a describe global to retrieve all all the objects and returns an array of DBSobjects */
- (NSArray *)describeGlobal
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableDictionary   *parmsDict;
  NSMutableDictionary   *queryParmDict;
  NSDictionary          *resultDict;
  NSDictionary          *queryResult;
  NSDictionary          *result;
  NSDictionary          *queryFault;
  NSArray               *sobjects;
  NSMutableArray        *objectList;
  unsigned              i;

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


  [logger log: LogDebug: @"[DBSoap describeGlobal] Describe Global dict is %d big\n", [resultDict count]];
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSDictionary *fault;
      NSDictionary *faultDetail;

      faultDetail = [queryFault objectForKey:@"detail"];
      fault = [faultDetail objectForKey:@"fault"];
      NSLog(@"fault: %@", fault);
      [logger log: LogStandard :@"[DBSoap describeGlobal] exception code: %@\n", [fault objectForKey:@"exceptionCode"]];
      [logger log: LogStandard :@"[DBSoap describeGlobal] exception message: %@\n", [fault objectForKey:@"exceptionMessage"]];
      [[NSException exceptionWithName:@"DBException" reason:[fault objectForKey:@"exceptionMessage"] userInfo:nil] raise];
    }

  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];
//  NSLog(@"result: %@", result);

  objectList = [NSMutableArray arrayWithCapacity:1];
  sobjects = [result objectForKey:@"sobjects"];

  for (i = 0; i < [sobjects count]; i++)
    {
      NSMutableDictionary *sObj;
      NSArray *propertiesArray;
      NSMutableDictionary *propertiesDict;
      DBSObject *dbObj;
      unsigned j;
    
      sObj = [sobjects objectAtIndex: i];
      propertiesArray = [sObj objectForKey: @"GWSCoderOrder"];
      propertiesDict = [NSMutableDictionary dictionaryWithCapacity: [propertiesArray count]];
      for (j = 0; j < [propertiesArray count]; j++)
	{
	  NSString *key;
	  
	  key = [propertiesArray objectAtIndex:j];
	  [propertiesDict setObject: [sObj objectForKey: key] forKey: key];
	}
      dbObj = [[DBSObject alloc] init];
      [dbObj setObjectProperties: propertiesDict];
      [objectList addObject: dbObj];
      [dbObj release];
    }

  return [NSArray arrayWithArray: objectList];
}

/* returns the currently stored list of object names
   if the list is nil, a describe global will be run to obtain it */
- (NSArray *)sObjects
{
  if (sObjectList == nil)
    sObjectList = [[self describeGlobal] retain];

  return sObjectList;
}

/* returns the currently stored list of object names
   if the list is nil, a describe global will be run to obtain it */
- (NSArray *)sObjectNames
{
  if (sObjectNamesList == nil)
    {
      unsigned i;

      if (sObjectList == nil)
	sObjectList = [[self describeGlobal] retain];

      sObjectNamesList = [[NSMutableArray arrayWithCapacity:1] retain];
      for (i = 0; i < [sObjectList count]; i++)
	[sObjectNamesList addObject: [[sObjectList objectAtIndex: i] name]];
    }
  
  return sObjectNamesList;
}

/** Force an udpate to the currently stored object  list */
- (void)updateObjects
{
  unsigned i;

  [sObjectList release];
  sObjectList = [[self describeGlobal] retain];

  [sObjectNamesList release];
  sObjectNamesList = [[NSMutableArray arrayWithCapacity:1] retain];
  for (i = 0; i < [sObjectList count]; i++)
    [sObjectNamesList addObject: [[sObjectList objectAtIndex: i] name]];
}

- (void)describeSObject: (NSString *)objectType toWriter:(DBCVSWriter *)writer
{
  unsigned       i;
  unsigned       size;
  DBSObject      *object;
  NSDictionary   *properties;
  NSArray        *fields;
  NSArray        *keys;
  NSMutableArray *set;

  
  object = [self describeSObject: objectType];
  fields = [object fieldNames];
  size = [fields count];
  
  if (size < 1)
    return;
  
  keys = [[object propertiesOfField: [fields objectAtIndex: 0]] allKeys];
  [writer setFieldNames:[NSArray arrayWithArray:keys] andWriteIt:YES];
  
  set = [[NSMutableArray alloc] init];
  
  for (i = 0; i < size; i++)
    {
      NSMutableArray *values;
      unsigned       j;
      NSString       *field;
      
      field = [fields objectAtIndex: i];
      properties = [object propertiesOfField: field];
      values = [NSMutableArray arrayWithCapacity:[keys count]];
      for (j = 0; j < [keys count]; j++)
        {
          id       obj;
          id       value;
          NSString *key;
      
          key = [keys objectAtIndex:j];
          obj = [properties objectForKey: key];
      
          value = obj;
          [values addObject:value];
        }
      [set addObject:values];
    }
  [writer writeDataSet:set];
  [set release];
}

- (DBSObject *)describeSObject: (NSString *)objectType
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
  unsigned              i;
  unsigned              size;
  NSMutableArray        *keys;
  DBSObject             *object;
  NSMutableDictionary   *propDict;


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

  [queryParmDict setObject: objectType forKey: @"sObjectType"];

  
  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [parmsDict setObject: queryParmDict forKey: @"describeSObject"];
  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];
  
  /* make the query */  
  resultDict = [service invokeMethod: @"describeSObject"
                parameters : parmsDict
		order : nil
		timeout : 90];
  
  queryFault = [resultDict objectForKey:@"GWSCoderFault"];
  if (queryFault != nil)
    {
      NSDictionary *fault;
      NSDictionary *faultDetail;

      faultDetail = [queryFault objectForKey:@"detail"];
      fault = [faultDetail objectForKey:@"fault"];
      NSLog(@"fault: %@", fault);
      [logger log: LogStandard :@"[DBSoap describeSObject] exception code: %@\n", [fault objectForKey:@"exceptionCode"]];
      [logger log: LogStandard :@"[DBSoap describeSObject] exception message: %@\n", [fault objectForKey:@"exceptionMessage"]];
      [[NSException exceptionWithName:@"DBException" reason:[fault objectForKey:@"exceptionMessage"] userInfo:nil] raise];
    }

  queryResult = [resultDict objectForKey:@"GWSCoderParameters"];
  result = [queryResult objectForKey:@"result"];

  records = [result objectForKey:@"fields"];
  size = [records count];

  /* if we have only one element, put it in an array */
  if (size == 1)
    records = [NSArray arrayWithObject:records];
  record = [records objectAtIndex:0];    
 

  keys = [NSMutableArray arrayWithArray:[record allKeys]];
  [keys removeObject:@"GWSCoderOrder"];

  object = [[DBSObject alloc] init];
  propDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [propDict setValue: objectType forKey: @"name"];
  [object setObjectProperties: propDict];

  for (i = 0; i < size; i++)
    {
      NSMutableDictionary *props;
      NSString *fieldName;
      
      record = [records objectAtIndex:i];
      props = [NSMutableDictionary dictionaryWithDictionary: record];
      [props removeObjectForKey:@"GWSCoderOrder"];
      fieldName = [props objectForKey: @"name"];
      [object setProperties:[NSDictionary dictionaryWithDictionary: props] forField: fieldName];
    }
    return [object autorelease];
}


- (NSMutableArray *)delete :(NSArray *)objectIdArray
{
  NSMutableDictionary   *headerDict;
  NSMutableDictionary   *sessionHeaderDict;
  NSMutableArray        *resultArray;
  NSEnumerator          *enumerator;
  unsigned              batchCounter;
  NSMutableArray        *batchObjArray;
  NSString              *idStr;

  if ([objectIdArray count] == 0)
    return nil;

  [logger log: LogDebug :@"[DBSoap delete] deleting %u objects...\n", [objectIdArray count]];

  /* prepare the header */
  sessionHeaderDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [sessionHeaderDict setObject: sessionId forKey: @"sessionId"];
  [sessionHeaderDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];

  headerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
  [headerDict setObject: sessionHeaderDict forKey: @"SessionHeader"];
  [headerDict setObject: GWSSOAPUseLiteral forKey: GWSSOAPUseKey];

  enumerator = [objectIdArray objectEnumerator];
  batchCounter = 0;
  batchObjArray = [[NSMutableArray arrayWithCapacity: MAX_BATCH_SIZE] retain];
  resultArray = [[NSMutableArray arrayWithCapacity:1] retain];
  
  do
    {
      NSMutableDictionary   *parmsDict;
      NSMutableDictionary   *queryParmDict;
      NSDictionary          *resultDict;
      NSDictionary          *queryResult;
      NSDictionary          *result;
      NSDictionary          *queryFault;
      NSMutableArray        *queryObjectsDict;

      idStr = [enumerator nextObject];
      if (idStr)
	{
	  [batchObjArray addObject: idStr];
	  batchCounter++;
	}
      /* did we fill a batch or did we reach the end? */
      if (batchCounter == MAX_BATCH_SIZE || !idStr)
	{
	  [logger log: LogDebug :@"[DBSoapNSLog delete ] batch obj-> %@\n", batchObjArray];
	  
	  /* prepare the parameters */
	  queryParmDict = [NSMutableDictionary dictionaryWithCapacity: 2];
	  [queryParmDict setObject: @"urn:partner.soap.sforce.com" forKey: GWSSOAPNamespaceURIKey];
	  
	  queryObjectsDict = [NSDictionary dictionaryWithObjectsAndKeys: batchObjArray, GWSSOAPValueKey, nil];
	  NSLog(@"Inner delete cycle. Deleting %u objects", [batchObjArray count]);
	  [queryParmDict setObject: queryObjectsDict forKey: @"ids"];
	  
	  parmsDict = [NSMutableDictionary dictionaryWithCapacity: 1];
	  [parmsDict setObject: queryParmDict forKey: @"delete"];
	  [parmsDict setObject: headerDict forKey:GWSSOAPMessageHeadersKey];  
  
	  /* make the query */  
	  resultDict = [service invokeMethod: @"delete"
				 parameters : parmsDict
				      order : nil
				    timeout : 90];

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

	  if (result != nil)
	    {
	      id resultRow;
	      NSEnumerator   *objEnu;
	      NSDictionary   *rowDict;
	      
	      /* if only one element gets returned, GWS can't interpret it as an array */
	      if (!([result isKindOfClass: [NSArray class]]))
		result = [NSArray arrayWithObject: result];
	      
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
		  
		  //		  NSLog(@"resultRow: %@", resultRow);
		  NSLog(@"errors: %@", errors);
		  NSLog(@"success: %@", success);
		  NSLog(@"message: %@", message);
		  NSLog(@"statusCode: %@", statusCode);
		  //		  NSLog(@"id: %@", sfId);
		  
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
	  NSLog(@"reiniting batch....");
	  [batchObjArray removeAllObjects];
	  batchCounter = 0;
	} /* of batch */
      NSLog(@"end of while loop...%@", idStr);
    }
  while (idStr);

  NSLog(@"%d result array: %@", [resultArray count], resultArray);
  [batchObjArray release];
  return [resultArray autorelease];
}

- (NSMutableArray *)deleteFromReader:(DBCVSReader *)reader
{
  NSMutableArray *objectsArray;
  NSMutableArray *resultArray;

  /* retrieve objects to delete */
  // FIXME perhaps this copy is useless
  objectsArray = [[NSMutableArray arrayWithArray:[reader readDataSet]] retain];
  [logger log: LogDebug :@"[DBSoap deleteFromReader] objects to delete: %@\n", objectsArray];
  NSLog(@"count of objects to delete: %d", [objectsArray count]);

  resultArray = [self delete:objectsArray];
  [objectsArray release];
  return resultArray;
}

- (NSString *)identifyObjectById:(NSString *)sfId
{
  NSString *devName;
  NSEnumerator *enu;
  NSString *name;
  BOOL found;
  NSString *prefixToIdentify;
  DBSObject *tempObj;

  devName = nil;
  found = NO;

  if (sfId == nil)
    return nil;

  if (!([sfId length] == 15 || [sfId length] == 18))
    return nil;

  prefixToIdentify = [sfId substringToIndex: 3];
  [logger log: LogInformative :@"[DBSoap identifyObjectById] identify: %@\n", prefixToIdentify];
  if (sObjectList == nil)
    [self updateObjects];

  [logger log: LogDebug :@"[DBSoap identifyObjectById] in %d objects\n", [sObjectList count]];
  enu = [sObjectList objectEnumerator];
  while (!found && (tempObj = [enu nextObject]))
    {
      [logger log: LogDebug :@"[DBSoap identifyObjectById] compare to: %@\n", [[tempObj objectProperties] objectForKey: @"keyPrefix"]];
      if ([[[tempObj objectProperties] objectForKey: @"keyPrefix"] isEqualToString: prefixToIdentify])
	{
	  name = [tempObj name];
	  [logger log: LogDebug :@"[DBSoap identifyObjectById] we found: %@\n", name];
	  found = YES;
	}
    }

  if (found)
    {
      [logger log: LogDebug :@"[DBSoap identifyObjectById] we found: %@\n", name];
      devName = [NSString stringWithString: name];
    }
  else
    [logger log: LogStandard :@"[DBSoap identifyObjectById] not found\n"];
  return devName;
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
