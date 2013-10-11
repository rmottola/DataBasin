/* 
   Project: DataBasin

   Copyright (C) 2008-2013 Free Software Foundation

   Author: Riccardo Mottola

   Created: 2008-11-13 22:44:02 +0100 by multix
   
   Application Controller

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

#import "AppController.h"
#import "DBSoap.h"
#import "DBSoapCSV.h"
#import "DBCVSWriter.h"
#import "DBCVSReader.h"
#import "DBLogger.h"
#import "DBProgress.h"
#import "Preferences.h"

#define DB_ENVIRONMENT_PRODUCTION 0
#define DB_ENVIRONMENT_SANDBOX    1

#define MAX_STORED_LOGINS 10

#if defined(__APPLE__) && (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
#define NSUTF16StringEncoding 999
#endif

@implementation AppController

+ (void)initialize
{
  NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

  /*
   * Register your app's defaults here by adding objects to the
   * dictionary, eg
   *
   * [defaults setObject:anObject forKey:keyForThatObject];
   *
   */
  
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)init
{
  if ((self = [super init]))
    {
      NSUserDefaults *defaults;

      defaults = [NSUserDefaults standardUserDefaults];

      logger = [[DBLogger alloc] init];
      [self reloadDefaults];

      loginDict = [defaults objectForKey: @"logins"];
      if (loginDict == nil)
	loginDict = [NSMutableDictionary dictionary];
      else
	loginDict = [NSMutableDictionary dictionaryWithDictionary:loginDict];
      [loginDict retain];

      /* if none found, set a reasonable default for the upload and insert batch size */
      if (![defaults objectForKey:@"UpBatchSize"])
	[defaults setObject:[NSNumber numberWithInt:100] forKey:@"UpBatchSize"];

    }
  return self;
}

- (void)dealloc
{
  [preferences release];
  [dbCsv release];
  [db release];
  [logger release];
  [loginDict release];
  [super dealloc];
}

- (void)awakeFromNib
{  
  objInspector = [[DBObjectInspector alloc] init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif
{
}

- (BOOL)applicationShouldTerminate:(id)sender
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotif
{
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName
{
  return NO;
}

- (void)reloadDefaults
{
  NSUserDefaults *defaults;
  id obj;
  
  defaults = [NSUserDefaults standardUserDefaults];
  
  obj = [defaults objectForKey: @"LogLevel"];
  /* if the log level is not set we set it to the standard level */
  if (obj == nil)
    {
      obj = [NSNumber numberWithInt: LogStandard];
      [defaults setObject:obj forKey: @"LogLevel"];
    }

  [logger setLogLevel: [obj intValue]];

  obj = [defaults objectForKey:@"UpBatchSize"];
  if (obj)
    {
      int size;

      size = [obj intValue];
      if (size > 0)
	[db setUpBatchSize:size];
    }
}

- (IBAction)showPrefPanel:(id)sender
{
  NSUserDefaults *defaults;
  
  if (!preferences)
    {
      preferences = [[Preferences alloc] init];
      [preferences setAppController:self];
    }
  
  [preferences showPrefPanel:sender];

  /* Apply defaults */
  defaults = [NSUserDefaults standardUserDefaults];
  [logger setLogLevel: [[defaults valueForKey: @"StringEncoding"] intValue]];
}


/* SESSION INSPECTOR */

- (IBAction)showSessionInspector:(id)sender
{
  [winSessionInspector makeKeyAndOrderFront:self];
}

/* USER INSPECTOR */

- (IBAction)showUserInspector:(id)sender
{
  [winUserInspector makeKeyAndOrderFront:self];
}

/* LOGGER */
- (IBAction)showLog:(id)sender
{
  [logger show:sender];
}

/* LOGIN */

- (IBAction)showLogin:(id)sender
{
  [winLogin makeKeyAndOrderFront:self];
}

- (IBAction)usernameFieldAction:(id)sender
{
  NSDictionary *loginSet;
  NSString *userName;
  NSString *token;
  NSNumber *envNum;

  userName = [fieldUserName stringValue];
  loginSet = [loginDict objectForKey:userName];
  if (loginSet == nil)
    return;
  
  [fieldPassword setStringValue:[loginSet objectForKey:@"password"]];
  token = [loginSet objectForKey:@"token"];
  if (token == nil)
    token = @"";
  [fieldToken setStringValue:token];

  envNum = [loginSet objectForKey:@"environment"];
  if (envNum)
    [popupEnvironment selectItemAtIndex:[envNum intValue]];
}

- (IBAction)doLogin:(id)sender
{
  NSString *userName;
  NSString *password;
  NSString *token;
  NSString *urlStr;
  NSURL    *url;
  NSDictionary *uInfo;
  BOOL useHttps;
  NSString *protocolString;
  NSMutableDictionary *loginSet;
  
  userName = [fieldUserName stringValue];
  password = [fieldPassword stringValue];
  token = [fieldToken stringValue];

  useHttps = NO;
  if ([[[NSUserDefaults standardUserDefaults] objectForKey: @"UseHttps"] intValue] == NSOnState)
    useHttps = YES;

  if (useHttps)
    protocolString = @"https://";
  else
    protocolString = @"http://";

  /* if present, we append the security token to the password */
  if (token != nil)
    password = [password stringByAppendingString:token];
    
  db = [[DBSoap alloc] init];
  [db setLogger: logger];
  dbCsv = [[DBSoapCSV alloc] init];
  [dbCsv setDBSoap:db];
  
  urlStr = nil;
  if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_PRODUCTION)
    urlStr = [protocolString stringByAppendingString: @"www.salesforce.com/services/Soap/u/25.0"];
  else if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_SANDBOX)
    urlStr = [protocolString stringByAppendingString: @"test.salesforce.com/services/Soap/u/25.0"];

  [logger log:LogStandard :@"[AppController doLogin] Url: %@\n", urlStr];  
  url = [NSURL URLWithString:urlStr];
  
  NS_DURING
    [db login :url :userName :password :useHttps];
    
    /* session inspector fields */
    [fieldSessionId setStringValue:[db sessionId]];
    [fieldServerUrl setStringValue:[db serverUrl]];
    if ([db passwordExpired])
      [fieldPwdExpired setStringValue: @"YES"];
    else
      [fieldPwdExpired setStringValue: @"NO"];
    
    /* user inspector fields */
    uInfo = [db userInfo];
    [fieldOrgName setStringValue: [uInfo valueForKey:@"organizationName"]];
    [fieldOrgId setStringValue: [uInfo valueForKey:@"organizationId"]];
    [fieldUserNameInsp setStringValue: [uInfo valueForKey:@"userName"]];
    [fieldUserFullName setStringValue: [uInfo valueForKey:@"userFullName"]];
    [fieldUserEmail setStringValue: [uInfo valueForKey:@"userEmail"]];
    [fieldUserId setStringValue: [uInfo valueForKey:@"userId"]];
    [fieldProfileId setStringValue: [uInfo valueForKey:@"profileId"]];
    [fieldRoleId setStringValue: [uInfo valueForKey:@"roleId"]];

  NS_HANDLER
    [logger log:LogStandard :@"Login failed\n"];
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
	return;
      }
    else
      {
	NSLog(@"Unexpected exception: %@", [localException name]);
      }
  NS_ENDHANDLER
  [logger log:LogStandard :@"[AppController doLogin] %@ logged in succesfully\n", userName];
  
  loginSet = [NSMutableDictionary dictionaryWithCapacity:4];
  [loginSet retain];
  [loginSet setObject:userName forKey:@"username"];
  [loginSet setObject:[fieldPassword stringValue] forKey:@"password"];
  if (token != nil)
    [loginSet setObject:token forKey:@"token"];
  [loginSet setObject:[NSDate date] forKey:@"lastlogin"];
  [loginSet setObject:[NSNumber numberWithInt:[popupEnvironment indexOfSelectedItem]] forKey:@"environment"];
  [loginDict setObject:loginSet forKey:userName];
  [loginSet release];
  NSLog(@"login dictionary is: %@", loginDict);
  if ([loginDict count] > MAX_STORED_LOGINS)
    { 
      NSEnumerator *e;
      id key;
      id oldKey;

      [logger log:LogInformative :@"[AppController doLogin] Maximum number of stored logins reached, removing oldest\n"];
      e = [loginDict keyEnumerator];
      oldKey = nil;
      while ((key = [e nextObject]))
	{
	  NSDictionary *currSet;
	  NSDictionary *oldSet;

	  if (oldKey == nil)
	    oldKey = key;
	  currSet = [loginDict objectForKey:key];
	  oldSet = [loginDict objectForKey:oldKey];
	  if ([[currSet objectForKey:@"lastlogin"] compare: [oldSet objectForKey:@"lastlogin"]] == NSOrderedAscending)
	    oldKey = key;
	}
      [logger log:LogInformative :@"[AppController doLogin] delete: %@\n", oldKey];
      [loginDict removeObjectForKey:oldKey];
    }
  [[NSUserDefaults standardUserDefaults] setObject:loginDict forKey: @"logins"];
}

/* UPDATE SOBJECT LIST */

- (IBAction)runDescribeGlobal:(id)sender
{
  NS_DURING
    [db updateObjects];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
}

/*  SELECT */

- (IBAction)showSelect:(id)sender
{
  [progIndSelect setDoubleValue:0];
  [winSelect makeKeyAndOrderFront:self];
}

- (IBAction)browseFileSelect:(id)sender
{
  NSSavePanel *savePanel;
  
  savePanel = [NSSavePanel savePanel];
  [savePanel setRequiredFileType:@"csv"];
  if ([savePanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [savePanel filename];
      [fieldFileSelect setStringValue:fileName];
    }
}

- (IBAction)executeSelect:(id)sender
{
  NSString      *statement;
  NSString      *filePath;
  NSFileHandle  *fileHandle;
  NSFileManager *fileManager;
  DBCVSWriter   *cvsWriter;
  DBProgress    *progress;
  
  statement = [fieldQuerySelect string];
  filePath = [fieldFileSelect stringValue];
  
  fileManager = [NSFileManager defaultManager];
  if ([fileManager createFileAtPath:filePath contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
      return;
    }  

  fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
  if (fileHandle == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
    }
  
  progress = [[DBProgress alloc] init];
  [progress setProgressIndicator: progIndSelect];
  [progress setRemainingTimeField: fieldRTSelect];
  [progress setLogger:logger];
  [progress reset];
  cvsWriter = [[DBCVSWriter alloc] initWithHandle:fileHandle];
  [cvsWriter setLogger:logger];

  NS_DURING
    [dbCsv query :statement queryAll:([queryAllSelect state] == NSOnState) toWriter:cvsWriter progressMonitor:progress];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
  [cvsWriter release];
  [fileHandle closeFile];
  [progress release];
}

/* INSERT */


- (IBAction)showInsert:(id)sender
{
  NSArray *objectNames;

  [winInsert makeKeyAndOrderFront:self];
  [progIndInsert setIndeterminate:YES];
  objectNames = nil;
  NS_DURING
    objectNames = [db sObjectNames];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
  [popupObjectsInsert removeAllItems];
  [popupObjectsInsert addItemsWithTitles: objectNames];
  [progIndInsert setIndeterminate:NO];
  [progIndInsert setDoubleValue:0];
}

- (IBAction)browseFileInsert:(id)sender
{
  NSOpenPanel *openPanel;
  
  openPanel = [NSOpenPanel openPanel];
//  [openPanel setRequiredFileType:@"csv"];
  if ([openPanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [openPanel filename];
      [fieldFileInsert setStringValue:fileName];
    }
}

- (IBAction)executeInsert:(id)sender
{
  NSString       *filePath;
  NSString       *resFilePath;
  DBCVSReader    *reader;
  NSString       *intoWhichObject;
  DBProgress     *progress;
  NSMutableArray *results;
  NSFileManager  *fileManager;
  NSFileHandle   *resFH;
  NSUserDefaults *defaults;
  DBCVSWriter    *resWriter;
  
  defaults = [NSUserDefaults standardUserDefaults];  
  filePath = [fieldFileInsert stringValue];
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];

  NSLog(@"writing results to: %@", resFilePath);

  filePath = [fieldFileInsert stringValue];
  
  intoWhichObject = [[[popupObjectsInsert selectedItem] title] retain];
  [logger log:LogInformative :@"[AppController executeInsert] object: %@\n", intoWhichObject];

  progress = [[DBProgress alloc] init];
  [progress setLogger:logger];
  [progress setProgressIndicator: progIndInsert];
  [progress setRemainingTimeField: fieldRTInsert];
  [progress reset];
  
  results = nil;
  reader = [[DBCVSReader alloc] initWithPath:filePath withLogger:logger];
  NS_DURING
    results = [dbCsv create:intoWhichObject fromReader:reader progressMonitor:progress];
    [results retain];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER


  fileManager = [NSFileManager defaultManager];
  if ([fileManager createFileAtPath:resFilePath contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
    }  

  resFH = [NSFileHandle fileHandleForWritingAtPath:resFilePath];
  if (resFH == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
    }
  else
    {
      resWriter = [[DBCVSWriter alloc] initWithHandle:resFH];
      [resWriter setLogger:logger];
      [resWriter setStringEncoding: [[defaults valueForKey: @"StringEncoding"] intValue]];
      
      [resWriter setFieldNames:[results objectAtIndex: 0] andWriteIt:YES];
      [resWriter writeDataSet: results];
      
      [resWriter release];
    }

  [reader release];
  [intoWhichObject release];
  [progress release];
  [results release];
}

/* UPDATE */


- (IBAction)showUpdate:(id)sender
{
  NSArray      *objectNames;
  
  [winUpdate makeKeyAndOrderFront:self];
  [progIndUpdate setIndeterminate:YES];
  objectNames  = nil;
  NS_DURING
    objectNames = [db sObjectNames];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
  [popupObjectsUpdate removeAllItems];
  [popupObjectsUpdate addItemsWithTitles: objectNames];
  [progIndUpdate setIndeterminate:NO];
  [progIndUpdate setDoubleValue:0]; 
}

- (IBAction)browseFileUpdate:(id)sender
{
  NSOpenPanel *openPanel;
  
  openPanel = [NSOpenPanel openPanel];
  //  [openPanel setRequiredFileType:@"csv"];
  if ([openPanel runModal] == NSOKButton)
    {
    NSString *fileName;
    
    fileName = [openPanel filename];
    [fieldFileUpdate setStringValue:fileName];
    }
}

- (IBAction)executeUpdate:(id)sender
{
  NSString       *filePath;
  NSString       *resFilePath;
  DBCVSReader    *reader;
  NSString       *whichObject;
  DBProgress     *progress;
  NSMutableArray *results;
  NSFileManager  *fileManager;
  NSFileHandle   *resFH;
  NSUserDefaults *defaults;
  DBCVSWriter    *resWriter;

  defaults = [NSUserDefaults standardUserDefaults];  
  filePath = [fieldFileUpdate stringValue];
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];

  [logger log:LogDebug: @"[AppController executeUpdate] writing results to: %@", resFilePath];
  
  progress = [[DBProgress alloc] init];
  [progress setLogger:logger];
  [progress setProgressIndicator: progIndUpdate];
  [progress setRemainingTimeField: fieldRTUpdate];
  [progress reset];

  whichObject = [[[popupObjectsUpdate selectedItem] title] retain];
  [logger log:LogInformative :@"[AppController executeUpdate] object: %@\n", whichObject];
  
  results = nil;
  reader = [[DBCVSReader alloc] initWithPath:filePath withLogger:logger];
  NS_DURING
    results = [dbCsv update:whichObject fromReader:reader progressMonitor:progress];
    [results retain];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER

  fileManager = [NSFileManager defaultManager];
  if ([fileManager createFileAtPath:resFilePath contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
    }  

  resFH = [NSFileHandle fileHandleForWritingAtPath:resFilePath];
  if (resFH == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
    }
  else
    {
      resWriter = [[DBCVSWriter alloc] initWithHandle:resFH];
      [resWriter setLogger:logger];
      [resWriter setStringEncoding: [[defaults valueForKey: @"StringEncoding"] intValue]];
      
      [resWriter setFieldNames:[results objectAtIndex: 0] andWriteIt:YES];
      [resWriter writeDataSet: results];
      
      [resWriter release];
    }
    
  [reader release];
  [whichObject release];
  [progress release];
  [results release];
}

/*  SELECT IDENTIFY */

- (IBAction)showSelectIdentify:(id)sender
{
  [winSelectIdentify makeKeyAndOrderFront:self];
  [progIndSelectIdent setIndeterminate:NO];
  [progIndSelectIdent setDoubleValue:0];
}

- (IBAction)browseFileSelectIdentifyIn:(id)sender
{
  NSOpenPanel *openPanel;
  
  openPanel = [NSOpenPanel openPanel];
  if ([openPanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [openPanel filename];
      [fieldFileSelectIdentifyIn setStringValue:fileName];
    }
}

- (IBAction)browseFileSelectIdentifyOut:(id)sender
{
  NSSavePanel *savePanel;
  
  savePanel = [NSSavePanel savePanel];
  [savePanel setRequiredFileType:@"csv"];
  if ([savePanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [savePanel filename];
      [fieldFileSelectIdentifyOut setStringValue:fileName];
    }
}

- (IBAction)executeSelectIdentify:(id)sender
{
  NSString      *statement;
  NSString      *filePathIn;
  NSString      *filePathOut;
  NSFileHandle  *fileHandleOut;
  NSFileManager *fileManager;
  DBCVSWriter   *cvsWriter;
  DBCVSReader   *cvsReader;
  DBProgress    *progress;
  int           batchSize;
  
  statement = [fieldQuerySelectIdentify string];
  filePathIn = [fieldFileSelectIdentifyIn stringValue];
  filePathOut = [fieldFileSelectIdentifyOut stringValue];

  batchSize = 0;
  switch ([[popupBatchSizeIdentify selectedItem] tag])
    {
    case 1:
      batchSize = 0;
      break;
    case 2:
      batchSize = 10;
      break;
    case 3:
      batchSize = 50;
      break;
    case 99:
      batchSize = -1;
      break;
    default:
      [logger log:LogStandard :@"[AppController executeSelectIdentify] unexpected batch size\n"];
    }
  [logger log:LogDebug :@"[AppController executeSelectIdentify] batch Size: %d\n", batchSize];
  
  fileManager = [NSFileManager defaultManager];

  cvsReader = [[DBCVSReader alloc] initWithPath:filePathIn withLogger:logger];

  if ([fileManager createFileAtPath:filePathOut contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
      [cvsReader release];
      return;
    }  

  fileHandleOut = [NSFileHandle fileHandleForWritingAtPath:filePathOut];
  if (fileHandleOut == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
      [cvsReader release];
      return;
    }

  cvsWriter = [[DBCVSWriter alloc] initWithHandle:fileHandleOut];
  [cvsWriter setLogger:logger];
  progress = [[DBProgress alloc] init];
  [progress setLogger:logger];
  [progress setProgressIndicator: progIndSelectIdent];
  [progress setRemainingTimeField: fieldRTSelectIdent];
  [progress reset];

  NS_DURING
    [dbCsv queryIdentify :statement queryAll:([queryAllSelectIdentify state] == NSOnState) fromReader:cvsReader toWriter:cvsWriter withBatchSize:batchSize progressMonitor:progress];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER

  [cvsReader release];
  [cvsWriter release];
  [fileHandleOut closeFile];
  
  [progress release];
}

/* DESCRIBE */

- (IBAction)showDescribe:(id)sender
{
  NSArray *objectNames;

  objectNames = [db sObjectNames];
  [popupObjectsDescribe removeAllItems];
  [popupObjectsDescribe addItemsWithTitles: objectNames];
    
  [winDescribe makeKeyAndOrderFront:self];
}

- (IBAction)browseFileDescribe:(id)sender
{
  NSSavePanel *savePanel;
  
  savePanel = [NSSavePanel savePanel];
  [savePanel setRequiredFileType:@"csv"];

  if ([savePanel runModal] == NSOKButton)
    {
      NSString *fileName;
    
      fileName = [savePanel filename];
      [fieldFileDescribe setStringValue:fileName];
    }
}

- (IBAction)executeDescribe:(id)sender
{
  NSString      *filePath;
  DBCVSWriter   *writer;
  NSString      *whichObject;
  NSFileManager *fileManager;
  NSFileHandle  *fileHandle;
  NSUserDefaults *defaults;

  defaults = [NSUserDefaults standardUserDefaults];
    
  filePath = [fieldFileDescribe stringValue];
  NSLog(@"%@", filePath);

  fileManager = [NSFileManager defaultManager];
  if ([fileManager createFileAtPath:filePath contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
      return;
    }  

  fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
  if (fileHandle == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
    }
  
  writer = [[DBCVSWriter alloc] initWithHandle:fileHandle];
  [writer setLogger:logger];
  [writer setStringEncoding: [[defaults valueForKey: @"StringEncoding"] intValue]];
  
  whichObject = [[[popupObjectsDescribe selectedItem] title] retain];
  NSLog(@"object: %@", whichObject);
  
  NS_DURING
    [dbCsv describeSObject:whichObject toWriter:writer];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
    
  [writer release];
  [whichObject release];
}


/* QUICK DELETE */

- (IBAction)showQuickDelete:(id)sender
{
  [winQuickDelete makeKeyAndOrderFront:self];
}


- (IBAction)quickDelete:(id)sender
{
  NSString  *objectId;
  NSArray   *idArray;
  NSMutableArray *resultArray;

  resultArray = nil;
  [fieldStatusQd setStringValue:@""];
  objectId = [fieldObjectIdQd stringValue];
  
  if (objectId == nil || [objectId length] == 0)
    return;
  
  idArray = [NSArray arrayWithObject:objectId];
  
  NS_DURING
    [fieldStatusQd setStringValue:@"Working..."];
    resultArray = [db delete: idArray progressMonitor:nil];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER

    if ([resultArray count] > 0)
      {
        NSDictionary *resultDict;
        NSString     *resultMsgStr;
      
        resultDict = [resultArray objectAtIndex:0];
        if ([[resultDict objectForKey:@"success"] isEqualToString:@"true"])
          [fieldStatusQd setStringValue:@"Deletion completed."];
        else
          {
            resultMsgStr = [resultDict objectForKey:@"message"];
            [fieldStatusQd setStringValue:[resultDict objectForKey:@"statusCode"]];
            [faultTextView setString:resultMsgStr];
            [faultPanel makeKeyAndOrderFront:nil];
          }
      }
    else
      {
	NSDictionary *resultDict;
	NSString     *resultMsgStr;

	resultDict = [resultArray objectAtIndex:0];
	resultMsgStr = [resultDict objectForKey:@"message"];
        [fieldStatusQd setStringValue:[resultDict objectForKey:@"statusCode"]];
        [faultTextView setString:resultMsgStr];
        [faultPanel makeKeyAndOrderFront:nil];
      }
}

/* DELETE */

- (IBAction)showDelete:(id)sender
{
  [winDelete makeKeyAndOrderFront:self];
}

- (IBAction)browseFileDelete:(id)sender
{
  NSOpenPanel *openPanel;
  
  openPanel = [NSOpenPanel openPanel];
//  [openPanel setRequiredFileType:@"csv"];
  if ([openPanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [openPanel filename];
      [fieldFileDelete setStringValue:fileName];
    }
}

- (IBAction)executeDelete:(id)sender
{
  NSString       *filePath;
  NSString       *resFilePath;
  DBCVSReader    *reader;
  DBCVSWriter    *resWriter;
  NSMutableArray *results;
  NSFileManager  *fileManager;
  NSFileHandle   *resFH;
  NSUserDefaults *defaults;
  DBProgress     *progress;

  defaults = [NSUserDefaults standardUserDefaults];  
  filePath = [fieldFileDelete stringValue];
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];

  NSLog(@"writing results to: %@", resFilePath);
    
  reader = [[DBCVSReader alloc] initWithPath:filePath byParsingHeaders:([checkSkipFirstLine state]==NSOnState) withLogger:logger];

  progress = [[DBProgress alloc] init];
  [progress setLogger:logger];
  [progress reset];

  results = nil;  
  NS_DURING
    results = [dbCsv deleteFromReader:reader progressMonitor:progress];
    [results retain];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER

  fileManager = [NSFileManager defaultManager];
  if ([fileManager createFileAtPath:resFilePath contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
    }  

  resFH = [NSFileHandle fileHandleForWritingAtPath:resFilePath];
  if (resFH == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
    }
  else
    {
      resWriter = [[DBCVSWriter alloc] initWithHandle:resFH];
      [resWriter setLogger:logger];
      [resWriter setStringEncoding: [[defaults valueForKey: @"StringEncoding"] intValue]];
      
      [resWriter setFieldNames:[results objectAtIndex: 0] andWriteIt:YES];
      [resWriter writeDataSet: results];
      
      [resWriter release];
    }
  [results release];
  [reader release];
  [progress release];
}

/* OBJECT INSPECTOR */

- (IBAction)showObjectInspector:(id)sender
{
  [objInspector setSoapHandler: db];
  [objInspector show];
}

@end
