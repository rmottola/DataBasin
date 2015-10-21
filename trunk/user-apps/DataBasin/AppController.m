/* 
   Project: DataBasin

   Copyright (C) 2008-2015 Free Software Foundation

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
#import <DataBasinKit/DBSoap.h>
#import <DataBasinKit/DBSoapCSV.h>
#import <DataBasinKit/DBCSVWriter.h>
#import <DataBasinKit/DBCSVReader.h>
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
  int size;
  
  defaults = [NSUserDefaults standardUserDefaults];
  
  obj = [defaults objectForKey: @"LogLevel"];
  /* if the log level is not set we set it to the standard level */
  if (obj == nil)
    {
      obj = [NSNumber numberWithInt: LogStandard];
      [defaults setObject:obj forKey: @"LogLevel"];
    }

  [logger setLogLevel: [obj intValue]];
  
  size = [defaults integerForKey:@"UpBatchSize"];
  if (size > 0)
    {
      [db setUpBatchSize:size];
    }

  size = [defaults integerForKey:@"DownBatchSize"];
  if (size > 0)
    {
      [db setDownBatchSize:size];
    }

  // FIXME here we should set the defaults of the CSV reader/writers
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
  [logger setLogLevel: [defaults integerForKey: @"StringEncoding"]];
}

- (void)showException:(NSException *)e
{
  NSLog(@"Exception: %@ - %@", e, [e reason]);
  [faultTextView setString:[e reason]];
  [faultPanel makeKeyAndOrderFront:self];
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
  NSURL    *url;
  NSDictionary *uInfo;
  NSMutableDictionary *loginSet;
  
  userName = [fieldUserName stringValue];
  password = [fieldPassword stringValue];
  token = [fieldToken stringValue];

  /* if present, we append the security token to the password */
  if (token != nil)
    password = [password stringByAppendingString:token];
    
  db = [[DBSoap alloc] init];
  [db setLogger: logger];
  dbCsv = [[DBSoapCSV alloc] init];
  [dbCsv setDBSoap:db];
  
  url = nil;
  if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_PRODUCTION)
    url = [DBSoap loginURLProduction];
  else if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_SANDBOX)
    url = [DBSoap loginURLTest];

  [logger log:LogStandard :@"[AppController doLogin] Url: %@\n", [url absoluteString]];  
  
  NS_DURING
    [db login :url :userName :password :YES];
    
    /* session inspector fields */
    [fieldSessionId setStringValue:[db sessionId]];
    [fieldServerUrl setStringValue:[db serverUrl]];
    if ([db passwordExpired])
      [fieldPwdExpired setStringValue: @"YES"];
    else
      [fieldPwdExpired setStringValue: @"NO"];
    
    /* user inspector fields */
    uInfo = [db userInfo];
    [fieldOrgName setStringValue: [uInfo objectForKey:@"organizationName"]];
    [fieldOrgId setStringValue: [uInfo objectForKey:@"organizationId"]];
    [fieldUserNameInsp setStringValue: [uInfo objectForKey:@"userName"]];
    [fieldUserFullName setStringValue: [uInfo objectForKey:@"userFullName"]];
    [fieldUserEmail setStringValue: [uInfo objectForKey:@"userEmail"]];
    [fieldUserId setStringValue: [uInfo objectForKey:@"userId"]];
    [fieldProfileId setStringValue: [uInfo objectForKey:@"profileId"]];
    [fieldRoleId setStringValue: [uInfo objectForKey:@"roleId"]];

  NS_HANDLER
    [logger log:LogStandard :@"Login failed\n"];
  [loginStatus setImage:[NSImage imageNamed:@"butt_red_16.tif"]];
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
	return;
      }
    else
      {
	NSLog(@"Unexpected exception: %@", [localException name]);
      }
  NS_ENDHANDLER
  [logger log:LogStandard :@"[AppController doLogin] %@ logged in succesfully\n", userName];
  
  [loginStatus setImage:[NSImage imageNamed:@"butt_green_16.tif"]];
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

- (void)resetSelectUI:(id)arg
{
  [buttonSelectExec setEnabled:YES];
  [buttonSelectStop setEnabled:NO];
}

- (void)performSelect:(id)arg
{
  NSString       *statement;
  NSString       *filePath;
  NSFileHandle   *fileHandle;
  NSFileManager  *fileManager;
  DBCSVWriter    *csvWriter;
  NSString       *str;
  NSUserDefaults *defaults;
  NSAutoreleasePool *arp;
  
  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];
  statement = [fieldQuerySelect string];
  filePath = [fieldFileSelect stringValue];
  
  fileManager = [NSFileManager defaultManager];
  if ([fileManager createFileAtPath:filePath contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
      [self performSelectorOnMainThread:@selector(resetSelectUI:) withObject:self waitUntilDone:NO];
      return;
    }  

  fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
  if (fileHandle == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
      [self performSelectorOnMainThread:@selector(resetSelectUI:) withObject:self waitUntilDone:NO];
      return;
    }

  selectProgress = [[DBProgress alloc] init];
  [selectProgress setProgressIndicator: progIndSelect];
  [selectProgress setRemainingTimeField: fieldRTSelect];
  [selectProgress setLogger:logger];
  [selectProgress reset];
  csvWriter = [[DBCSVWriter alloc] initWithHandle:fileHandle];
  [csvWriter setLogger:logger];
  [csvWriter setWriteFieldsOrdered:([orderedWritingSelect state] == NSOnState)];
  [csvWriter setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
  str = [defaults stringForKey:@"CSVWriteQualifier"];
  if (str)
    [csvWriter setQualifier:str];
  str = [defaults stringForKey:@"CSVWriteSeparator"];
  if (str)
    [csvWriter setSeparator:str];
  
  NS_DURING
    [dbCsv query :statement queryAll:([queryAllSelect state] == NSOnState) toWriter:csvWriter progressMonitor:selectProgress];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER
  [csvWriter release];
  [fileHandle closeFile];
  [selectProgress release];
  selectProgress = nil;
  [self performSelectorOnMainThread:@selector(resetSelectUI:) withObject:self waitUntilDone:NO];
  [arp drain];
}

- (IBAction)executeSelect:(id)sender
{
  [buttonSelectExec setEnabled:NO];
  [buttonSelectStop setEnabled:YES];
  [NSThread detachNewThreadSelector:@selector(performSelect:) toTarget:self withObject:nil];
}


- (IBAction)stopSelect:(id)sender
{
  [selectProgress setShouldStop:YES];
}

/* INSERT */


- (void)resetInsertUI:(id)arg
{
  [buttonInsertExec setEnabled:YES];
  [buttonInsertStop setEnabled:NO];
}


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
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
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

- (void)performInsert:(id)arg
{
  NSString       *filePath;
  NSString       *resFilePath;
  DBCSVReader    *reader;
  NSString       *intoWhichObject;
  NSMutableArray *results;
  NSFileManager  *fileManager;
  NSFileHandle   *resFH;
  NSUserDefaults *defaults;
  DBCSVWriter    *resWriter;
  NSString       *str;
  NSAutoreleasePool *arp;
  
  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];  
  filePath = [fieldFileInsert stringValue];
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];

  NSLog(@"writing results to: %@", resFilePath);

  filePath = [fieldFileInsert stringValue];
  
  intoWhichObject = [[[popupObjectsInsert selectedItem] title] retain];
  [logger log:LogInformative :@"[AppController executeInsert] object: %@\n", intoWhichObject];

  insertProgress = [[DBProgress alloc] init];
  [insertProgress setLogger:logger];
  [insertProgress setProgressIndicator: progIndInsert];
  [insertProgress setRemainingTimeField: fieldRTInsert];
  [insertProgress reset];
  
  results = nil;
  reader = [[DBCSVReader alloc] initWithPath:filePath withLogger:logger];
  str = [defaults stringForKey:@"CSVReadQualifier"];
  if (str)
    [reader setQualifier:str];
  str = [defaults stringForKey:@"CSVReadSeparator"];
  if (str)
    [reader setSeparator:str];
  [reader parseHeaders];

  NS_DURING
    results = [dbCsv create:intoWhichObject fromReader:reader progressMonitor:insertProgress];
    [results retain];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
        [insertProgress release];
        [self resetInsertUI:self];
        [arp drain];
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
      if (results != nil && [results count] > 0)
        {
          resWriter = [[DBCSVWriter alloc] initWithHandle:resFH];
          [resWriter setLogger:logger];
          [resWriter setStringEncoding: [defaults integerForKey: @"StringEncoding"]];
          str = [defaults stringForKey:@"CSVWriteQualifier"];
          if (str)
            [resWriter setQualifier:str];
          str = [defaults stringForKey:@"CSVWriteSeparator"];
          if (str)
            [resWriter setSeparator:str];
          
          
          [resWriter setFieldNames:[results objectAtIndex: 0] andWriteThem:YES];
          [resWriter writeDataSet: results];
          
          [resWriter release];
        }
      else
        {
          [logger log:LogStandard :@"[AppController executeInsert] No Results"];
        }
    }

  [reader release];
  [intoWhichObject release];
  [insertProgress release];
  [results release];
  [arp drain];
}

- (IBAction)executeInsert:(id)sender
{
  [buttonInsertExec setEnabled:NO];
  [buttonInsertStop setEnabled:YES];
  [NSThread detachNewThreadSelector:@selector(performInsert:) toTarget:self withObject:nil];
}

- (IBAction)stopInsert:(id)sender
{
  [insertProgress setShouldStop:YES];
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
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
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

- (void)resetUpdateUI:(id)arg
{
  [buttonUpdateExec setEnabled:YES];
  [buttonUpdateStop setEnabled:NO];
}

- (void)performUpdate:(id)arg
{
  NSString       *filePath;
  NSString       *resFilePath;
  DBCSVReader    *reader;
  NSString       *whichObject;
  NSMutableArray *results;
  NSFileManager  *fileManager;
  NSFileHandle   *resFH;
  NSUserDefaults *defaults;
  DBCSVWriter    *resWriter;
  NSString       *str;
  NSAutoreleasePool *arp;
  
  arp = [NSAutoreleasePool new];
  
  defaults = [NSUserDefaults standardUserDefaults];  
  filePath = [fieldFileUpdate stringValue];
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];

  [logger log:LogDebug: @"[AppController executeUpdate] writing results to: %@", resFilePath];
  
  updateProgress = [[DBProgress alloc] init];
  [updateProgress setLogger:logger];
  [updateProgress setProgressIndicator: progIndUpdate];
  [updateProgress setRemainingTimeField: fieldRTUpdate];
  [updateProgress reset];

  whichObject = [[[popupObjectsUpdate selectedItem] title] retain];
  [logger log:LogInformative :@"[AppController executeUpdate] object: %@\n", whichObject];
  
  results = nil;
  reader = [[DBCSVReader alloc] initWithPath:filePath withLogger:logger];
  str = [defaults stringForKey:@"CSVReadQualifier"];
  if (str)
    [reader setQualifier:str];
  str = [defaults stringForKey:@"CSVReadSeparator"];
  if (str)
    [reader setSeparator:str];
  [reader parseHeaders];

  NS_DURING
    results = [dbCsv update:whichObject fromReader:reader progressMonitor:updateProgress];
    [results retain];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
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
      if (results != nil && [results count] > 0)
        {
          resWriter = [[DBCSVWriter alloc] initWithHandle:resFH];
          [resWriter setLogger:logger];
          [resWriter setStringEncoding: [defaults integerForKey: @"StringEncoding"]];
          str = [defaults stringForKey:@"CSVWriteQualifier"];
          if (str)
            [resWriter setQualifier:str];
          str = [defaults stringForKey:@"CSVWriteSeparator"];
          if (str)
            [resWriter setSeparator:str];

          
          [resWriter setFieldNames:[results objectAtIndex: 0] andWriteThem:YES];
          [resWriter writeDataSet: results];
          
          [resWriter release];
        }
      else
        {
          [logger log:LogStandard :@"[AppController executeUpdate] No Results"];
        }
    }
    
  [reader release];
  [whichObject release];
  [updateProgress release];
  updateProgress = nil;
  [results release];
  [self performSelectorOnMainThread:@selector(resetUpdateUI:) withObject:self waitUntilDone:NO];
  [arp drain];
}

- (IBAction)executeUpdate:(id)sender
{
  [buttonUpdateExec setEnabled:NO];
  [buttonUpdateStop setEnabled:YES];
  [NSThread detachNewThreadSelector:@selector(performUpdate:) toTarget:self withObject:nil];
}


- (IBAction)stopUpdate:(id)sender
{
  [updateProgress setShouldStop:YES];
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

- (void)resetSelectIdentUI:(id)arg
{
  [buttonSelectIdentExec setEnabled:YES];
  [buttonSelectIdentStop setEnabled:NO];
}

- (void)performSelectIdentify:(id)arg
{
  NSString       *statement;
  NSString       *filePathIn;
  NSString       *filePathOut;
  NSFileHandle   *fileHandleOut;
  NSFileManager  *fileManager;
  DBCSVWriter    *csvWriter;
  DBCSVReader    *csvReader;
  int            batchSize;
  NSString       *str;
  NSUserDefaults *defaults;
  NSAutoreleasePool *arp;

  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];

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
    case 4:
      batchSize = 100;
      break;      
    case 5:
      batchSize = 200;
      break;      
    case 99:
      batchSize = -1;
      break;
    default:
      [logger log:LogStandard :@"[AppController executeSelectIdentify] unexpected batch size\n"];
    }
  [logger log:LogDebug :@"[AppController executeSelectIdentify] batch Size: %d\n", batchSize];
  
  fileManager = [NSFileManager defaultManager];

  csvReader = [[DBCSVReader alloc] initWithPath:filePathIn withLogger:logger];
  str = [defaults stringForKey:@"CSVReadQualifier"];
  if (str)
    [csvReader setQualifier:str];
  str = [defaults stringForKey:@"CSVReadSeparator"];
  if (str)
    [csvReader setSeparator:str];
  [csvReader parseHeaders];
  if ([fileManager createFileAtPath:filePathOut contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
      [csvReader release];
      [arp drain];
      [self performSelectorOnMainThread:@selector(resetSelectIdentUI:) withObject:self waitUntilDone:NO];
      return;
    }  

  fileHandleOut = [NSFileHandle fileHandleForWritingAtPath:filePathOut];
  if (fileHandleOut == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
      [csvReader release];
      [arp drain];
      [self performSelectorOnMainThread:@selector(resetSelectIdentUI:) withObject:self waitUntilDone:NO];
      return;
    }

  csvWriter = [[DBCSVWriter alloc] initWithHandle:fileHandleOut];
  [csvWriter setLogger:logger];
  [csvWriter setWriteFieldsOrdered:([orderedWritingSelectIdent state] == NSOnState)];
  str = [defaults stringForKey:@"CSVWriteQualifier"];
  if (str)
    [csvWriter setQualifier:str];
  str = [defaults stringForKey:@"CSVWriteSeparator"];
  if (str)
    [csvWriter setSeparator:str];
  [csvWriter setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
  selectIdentProgress = [[DBProgress alloc] init];
  [selectIdentProgress setLogger:logger];
  [selectIdentProgress setProgressIndicator: progIndSelectIdent];
  [selectIdentProgress setRemainingTimeField: fieldRTSelectIdent];
  [selectIdentProgress reset];

  NS_DURING
    [dbCsv queryIdentify :statement queryAll:([queryAllSelectIdentify state] == NSOnState) fromReader:csvReader toWriter:csvWriter withBatchSize:batchSize progressMonitor:selectIdentProgress];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER

  [csvReader release];
  [csvWriter release];
  [fileHandleOut closeFile];
  
  [selectIdentProgress release];
  selectIdentProgress = nil;
  [self performSelectorOnMainThread:@selector(resetSelectIdentUI:) withObject:self waitUntilDone:NO];
  [arp drain];
}

- (IBAction)executeSelectIdentify:(id)sender
{
  [buttonSelectIdentExec setEnabled:NO];
  [buttonSelectIdentStop setEnabled:YES];
  [NSThread detachNewThreadSelector:@selector(performSelectIdentify:) toTarget:self withObject:nil];
}


- (IBAction)stopSelectIdentify:(id)sender
{
  [selectIdentProgress setShouldStop:YES];
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
  NSString       *filePath;
  DBCSVWriter    *writer;
  NSString       *whichObject;
  NSFileManager  *fileManager;
  NSFileHandle   *fileHandle;
  NSUserDefaults *defaults;
  NSString       *str;

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
  
  writer = [[DBCSVWriter alloc] initWithHandle:fileHandle];
  [writer setLogger:logger];
  [writer setStringEncoding: [defaults integerForKey: @"StringEncoding"]];
  str = [defaults stringForKey:@"CSVWriteQualifier"];
  if (str)
    [writer setQualifier:str];
  str = [defaults stringForKey:@"CSVWriteSeparator"];
  if (str)
    [writer setSeparator:str];
  
  whichObject = [[[popupObjectsDescribe selectedItem] title] retain];
  NSLog(@"object: %@", whichObject);
  
  NS_DURING
    [dbCsv describeSObject:whichObject toWriter:writer];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
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

- (void)resetQuickDeleteUI:(id)arg
{
  [buttonQuickDeleteExec setEnabled:YES];
}


- (void)performQuickDelete:(id)sender
{
  NSString  *objectId;
  NSArray   *idArray;
  NSMutableArray *resultArray;
  NSAutoreleasePool *arp;
  GWSService     *serv;
  DBSoap         *dbSoap;
  
  arp = [NSAutoreleasePool new];
  
  resultArray = nil;
  [fieldStatusQd setStringValue:@""];
  objectId = [fieldObjectIdQd stringValue];
  
  if (objectId == nil || [objectId length] == 0)
    return;

  /* we clone the soap instance and pass the session, so that the method can run in a separate thread */
  dbSoap = [[DBSoap alloc] init];
  serv = [DBSoap gwserviceForDBSoap];
  [dbSoap setSessionId:[db sessionId]];
  [serv setURL:[db serverUrl]];  
  [dbSoap setService:serv];
  
  idArray = [NSArray arrayWithObject:objectId];
  
  NS_DURING
    [fieldStatusQd setStringValue:@"Working..."];
    resultArray = [dbSoap delete: idArray progressMonitor:nil];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
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
  [self performSelectorOnMainThread:@selector(resetQuickDeleteUI:) withObject:self waitUntilDone:NO];    
  [arp drain];
}

- (IBAction)quickDelete:(id)sender
{
  [buttonQuickDeleteExec setEnabled:NO];
  [NSThread detachNewThreadSelector:@selector(performQuickDelete:) toTarget:self withObject:nil];
}

/* DELETE */

- (IBAction)showDelete:(id)sender
{
  [winDelete makeKeyAndOrderFront:self];
  [progIndDelete setIndeterminate:NO];
  [progIndDelete setDoubleValue:0];
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

- (void)resetDeleteUI:(id)arg
{
  [buttonDeleteExec setEnabled:YES];
  [buttonDeleteStop setEnabled:NO];
}

- (void)performDelete:(id)arg
{
  NSString       *filePath;
  NSString       *resFilePath;
  DBCSVReader    *reader;
  DBCSVWriter    *resWriter;
  NSMutableArray *results;
  NSFileManager  *fileManager;
  NSFileHandle   *resFH;
  NSUserDefaults *defaults;
  NSString       *str;
  NSAutoreleasePool *arp;

  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];  
  filePath = [fieldFileDelete stringValue];
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];

  NSLog(@"writing results to: %@", resFilePath);
    
  reader = [[DBCSVReader alloc] initWithPath:filePath byParsingHeaders:([checkSkipFirstLine state]==NSOnState) withLogger:logger];
  str = [defaults stringForKey:@"CSVReadQualifier"];
  if (str)
    [reader setQualifier:str];
  str = [defaults stringForKey:@"CSVReadSeparator"];
  if (str)
    [reader setSeparator:str];
  /* no need to reparse the headers since they are not used, just skipped */

  deleteProgress = [[DBProgress alloc] init];
  [deleteProgress setProgressIndicator: progIndDelete];
  [deleteProgress setRemainingTimeField: fieldRTDelete];
  [deleteProgress setLogger:logger];
  [deleteProgress reset];

  results = nil;  
  NS_DURING
    results = [dbCsv deleteFromReader:reader progressMonitor:deleteProgress];
    [results retain];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
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
      resWriter = [[DBCSVWriter alloc] initWithHandle:resFH];
      [resWriter setLogger:logger];
      [resWriter setStringEncoding: [defaults integerForKey: @"StringEncoding"]];
      str = [defaults stringForKey:@"CSVWriteQualifier"];
      if (str)
        [resWriter setQualifier:str];
      str = [defaults stringForKey:@"CSVWriteSeparator"];
      if (str)
        [resWriter setSeparator:str];
      
      [resWriter setFieldNames:[results objectAtIndex: 0] andWriteThem:YES];
      [resWriter writeDataSet: results];
      
      [resWriter release];
    }
  [results release];
  [reader release];
  [deleteProgress release];
  deleteProgress = nil;
  [self performSelectorOnMainThread:@selector(resetDeleteUI:) withObject:self waitUntilDone:NO];
  [arp drain];
}

- (IBAction)executeDelete:(id)sender
{
  [buttonDeleteExec setEnabled:NO];
  [buttonDeleteStop setEnabled:YES];
  [NSThread detachNewThreadSelector:@selector(performDelete:) toTarget:self withObject:nil];
}

- (IBAction)stopDelete:(id)sender
{
  [deleteProgress setShouldStop:YES];
}

/* OBJECT INSPECTOR */

- (IBAction)showObjectInspector:(id)sender
{
  [objInspector setSoapHandler: db];
  [objInspector show];
}

@end
