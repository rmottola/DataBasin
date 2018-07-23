/* 
   Project: DataBasin

   Copyright (C) 2008-2018 Free Software Foundation

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
#import <DataBasinKit/DBFileWriter.h>
#import <DataBasinKit/DBCSVWriter.h>
#import <DataBasinKit/DBHTMLWriter.h>
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
  unsigned size;
  
  defaults = [NSUserDefaults standardUserDefaults];

  obj = [defaults objectForKey: @"LogLevel"];
  /* if the log level is not set we set it to the standard level */
  if (obj == nil)
    {
      obj = [NSNumber numberWithInt: LogStandard];
      [defaults setObject:obj forKey: @"LogLevel"];
    }
  [logger setLogLevel: [obj intValue]];

  obj = [defaults objectForKey: @"StringEncoding"];
  if (obj == nil)
    {
      obj = [NSNumber numberWithInt: NSUTF8StringEncoding];
      [defaults setObject:obj forKey: @"StringEncoding"];
    }
	
  size = [defaults integerForKey:@"UpBatchSize"];
  if (size == 0)
    {
      size = 10;
      [defaults setInteger:size forKey:@"UpBatchSize"];
    }
  [db setUpBatchSize:size];

  size = [defaults integerForKey:@"DownBatchSize"];
  if (size == 0)
    {
      size = 100;
      [defaults setInteger:size forKey:@"DownBatchSize"];
    }
  [db setDownBatchSize:size];

  size = [defaults integerForKey:@"MaxSOQLQueryLength"];
  if (size == 0)
    {
      size = MAX_SOQL_LENGTH;
      [defaults setInteger:size forKey:@"MaxSOQLQueryLength"];
    }
  [db setMaxSOQLLength:size];

  [db setEnableFieldTypesDescribeForQuery:[[defaults objectForKey:@"DescribeFieldTypesInQueries"] boolValue]];

  [defaults synchronize];

  // FIXME here we should set the defaults of the CSV reader/writers
}

- (IBAction)showPrefPanel:(id)sender
{
  if (!preferences)
    {
      preferences = [[Preferences alloc] init];
      [preferences setAppController:self];
    }
  
  [preferences showPrefPanel:sender];
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
  NSUserDefaults *defaults;
  BOOL useHTTPS;
  
  useHTTPS = YES;
  if ([[NSProcessInfo processInfo] operatingSystem] == NSMACHOperatingSystem)
    {
      NSString *v;
      NSRange rangeOf10;
    
      v = [[NSProcessInfo processInfo] operatingSystemVersionString];
      NSLog(@"OS Version: %@", v);
      rangeOf10 = [v rangeOfString:@" 10."];
      if (rangeOf10.location != NSNotFound)
        {
          NSRange rangeOfDot;
        
          rangeOfDot = [v rangeOfString:@"." options:0 range:NSMakeRange(rangeOf10.location+rangeOf10.length, [v length]-(rangeOf10.location+rangeOf10.length))];
          if (rangeOfDot.location != NSNotFound)
            {
              NSString *minorStr;
              int minor;
              
              minorStr = [v substringWithRange:NSMakeRange(rangeOf10.location + rangeOf10.length, rangeOfDot.location - (rangeOf10.location + rangeOf10.length))];
              minor = [minorStr intValue];
              if (minor > 1 && minor < 10)
                useHTTPS = NO;
              NSLog(@"minor version %@: %d", minorStr, minor);
            }
        }
    }
  
  userName = [fieldUserName stringValue];
  password = [fieldPassword stringValue];
  token = [fieldToken stringValue];

  defaults = [NSUserDefaults standardUserDefaults];
    
  /* if present, we append the security token to the password */
  if (token != nil)
    password = [password stringByAppendingString:token];

  db = [[DBSoap alloc] init];
  [db setLogger: logger];
  [db setUpBatchSize:[[defaults objectForKey:@"UpBatchSize"] intValue]];
  [db setDownBatchSize:[[defaults objectForKey:@"DownBatchSize"] intValue]];
  [db setMaxSOQLLength:[[defaults objectForKey:@"MaxSOQLQueryLength"] intValue]];
  [db setEnableFieldTypesDescribeForQuery:[[defaults objectForKey:@"DescribeFieldTypesInQueries"] boolValue]];
  dbCsv = [[DBSoapCSV alloc] init];
  [dbCsv setDBSoap:db];
  
  url = nil;
  if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_PRODUCTION)
    url = [DBSoap loginURLProduction];
  else if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_SANDBOX)
    url = [DBSoap loginURLTest];

  [logger log:LogStandard :@"[AppController doLogin] Url: %@\n", [url absoluteString]];  
  
  NS_DURING
    [db login :url :userName :password :useHTTPS];
    
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
	  if ([(NSString *)[currSet objectForKey:@"lastlogin"] compare: [oldSet objectForKey:@"lastlogin"]] == NSOrderedAscending)
	    oldKey = key;
	}
      [logger log:LogInformative :@"[AppController doLogin] delete: %@\n", oldKey];
      [loginDict removeObjectForKey:oldKey];
    }
  [[NSUserDefaults standardUserDefaults] setObject:loginDict forKey: @"logins"];

  /* set or update soap handlers */
  [objInspector setSoapHandler:db];
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
  NSArray *types;
  
  types = [NSArray arrayWithObjects:@"csv", @"html", @"xls", nil];
  savePanel = [NSSavePanel savePanel];
  [savePanel setAllowedFileTypes:types];
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
  DBFileWriter   *fileWriter;
  NSString       *str;
  NSUserDefaults *defaults;
  NSAutoreleasePool *arp;
  NSString       *fileType;
  
  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];
  statement = [fieldQuerySelect string];
  filePath = [fieldFileSelect stringValue];
  fileType = DBFileFormatCSV;
  if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"html"])
    fileType = DBFileFormatHTML;
  else if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"xls"])
    fileType = DBFileFormatXLS;
  
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
  fileWriter = nil;
  
  if (fileType == DBFileFormatCSV)
    {
      fileWriter = [[DBCSVWriter alloc] initWithHandle:fileHandle];
      [(DBCSVWriter *)fileWriter setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
      str = [defaults stringForKey:@"CSVWriteQualifier"];
      if (str)
        [(DBCSVWriter *)fileWriter setQualifier:str];
      str = [defaults stringForKey:@"CSVWriteSeparator"];
      if (str)
        [(DBCSVWriter *)fileWriter setSeparator:str];
    }
  else if (fileType == DBFileFormatHTML || fileType == DBFileFormatXLS)
    {
      fileWriter = [[DBHTMLWriter alloc] initWithHandle:fileHandle];
      if (fileType == DBFileFormatXLS)
        [fileWriter setFileFormat:DBFileFormatXLS];
      else
        [fileWriter setFileFormat:DBFileFormatHTML];
    }
  [fileWriter setWriteFieldsOrdered:([orderedWritingSelect state] == NSOnState)];
  [fileWriter setLogger:logger];
  [fileWriter setStringEncoding: [defaults integerForKey: @"StringEncoding"]];
  NSLog(@"fileType is: %@, writer: %@", fileType, fileWriter);
  NS_DURING
    [dbCsv query :statement queryAll:([queryAllSelect state] == NSOnState) toWriter:fileWriter progressMonitor:selectProgress];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER

  [fileWriter release];
  [fileHandle closeFile];
  [selectProgress release];
  selectProgress = nil;
  [self performSelectorOnMainThread:@selector(resetSelectUI:) withObject:self waitUntilDone:NO];
  [arp release];
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
  NSMutableArray *filteredObjectNames;
  BOOL filterShare;
  BOOL filterHistory;
  NSUInteger i;
  NSUserDefaults *defaults;

  defaults = [NSUserDefaults standardUserDefaults];
  filterShare = [defaults boolForKey:@"FilterObjects_Share"];
  filterHistory = [defaults boolForKey:@"FilterObjects_History"];
  
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
    
  filteredObjectNames = [[NSMutableArray alloc] initWithCapacity:1];
  for (i = 0; i < [objectNames count]; i++)
    {
      NSString *name;

      name = [objectNames objectAtIndex:i];
      if (filterShare && [name hasSuffix: @"Share"])
	name = nil;
      if (filterHistory && [name hasSuffix: @"History"])
	name = nil;

      if (name)
	[filteredObjectNames addObject:name];
    }
  [popupObjectsInsert removeAllItems];
  [popupObjectsInsert addItemsWithTitles: filteredObjectNames];
  [progIndInsert setIndeterminate:NO];
  [progIndInsert setDoubleValue:0];
  [filteredObjectNames release];
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
  if (filePath == nil)
    {
      [logger log:LogInformative :@"[AppController performInsert] nil file paths\n"];
      return;
    }
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];

  NSLog(@"writing results to: %@", resFilePath);
  
  intoWhichObject = [[[popupObjectsInsert selectedItem] title] retain];
  [logger log:LogInformative :@"[AppController performInsert] object: %@\n", intoWhichObject];

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
        [self resetInsertUI:self];
      }
  NS_ENDHANDLER


  fileManager = [NSFileManager defaultManager];
  if (results && [fileManager createFileAtPath:resFilePath contents:nil attributes:nil] == NO)
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
  insertProgress = nil;
  [self performSelectorOnMainThread:@selector(resetInsertUI:) withObject:self waitUntilDone:NO];
  [results release];
  [arp release];
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
  NSMutableArray *filteredObjectNames;
  BOOL filterShare;
  BOOL filterHistory;
  NSUInteger i;
  NSUserDefaults *defaults;

  defaults = [NSUserDefaults standardUserDefaults];
  filterShare = [defaults boolForKey:@"FilterObjects_Share"];
  filterHistory = [defaults boolForKey:@"FilterObjects_History"];

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

  filteredObjectNames = [[NSMutableArray alloc] initWithCapacity:1];
  for (i = 0; i < [objectNames count]; i++)
    {
      NSString *name;

      name = [objectNames objectAtIndex:i];
      if (filterShare && [name hasSuffix: @"Share"])
	name = nil;
      if (filterHistory && [name hasSuffix: @"History"])
	name = nil;

      if (name)
	[filteredObjectNames addObject:name];
    }
  
  [popupObjectsUpdate removeAllItems];
  [popupObjectsUpdate addItemsWithTitles: filteredObjectNames];
  [progIndUpdate setIndeterminate:NO];
  [progIndUpdate setDoubleValue:0];
  [filteredObjectNames release];
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
    else
      {
        [localException raise];
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
  [arp release];
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
  NSArray *types;
  
  types = [NSArray arrayWithObjects:@"csv", @"html", @"xls", nil];  
  savePanel = [NSSavePanel savePanel];
  [savePanel setAllowedFileTypes:types];
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
  DBFileWriter   *fileWriter;
  DBCSVReader    *csvReader;
  NSString       *fileTypeOut;
  int            batchSize;
  NSString       *str;
  NSUserDefaults *defaults;
  NSAutoreleasePool *arp;

  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];

  statement = [fieldQuerySelectIdentify string];
  filePathIn = [fieldFileSelectIdentifyIn stringValue];
  filePathOut = [fieldFileSelectIdentifyOut stringValue];
  fileTypeOut = DBFileFormatCSV;
  if ([[[filePathOut pathExtension] lowercaseString] isEqualToString:@"html"])
    fileTypeOut = DBFileFormatHTML;
  else if ([[[filePathOut pathExtension] lowercaseString] isEqualToString:@"xls"])
    fileTypeOut = DBFileFormatXLS;
  
  batchSize = 0;
  switch ([[popupBatchSizeIdentify selectedItem] tag])
    {
    case 1:
      batchSize = 1;
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
      [arp release];
      [self performSelectorOnMainThread:@selector(resetSelectIdentUI:) withObject:self waitUntilDone:NO];
      return;
    }  

  fileHandleOut = [NSFileHandle fileHandleForWritingAtPath:filePathOut];
  if (fileHandleOut == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
      [csvReader release];
      [arp release];
      [self performSelectorOnMainThread:@selector(resetSelectIdentUI:) withObject:self waitUntilDone:NO];
      return;
    }

  fileWriter = nil;
  if (fileTypeOut == DBFileFormatCSV)
    {
      fileWriter = [[DBCSVWriter alloc] initWithHandle:fileHandleOut];
      str = [defaults stringForKey:@"CSVWriteQualifier"];
      if (str)
	[(DBCSVWriter *)fileWriter setQualifier:str];
      str = [defaults stringForKey:@"CSVWriteSeparator"];
      if (str)
	[(DBCSVWriter *)fileWriter setSeparator:str];
      [(DBCSVWriter *)fileWriter setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
    }
  else if (fileTypeOut == DBFileFormatHTML || fileTypeOut == DBFileFormatXLS)
    {
      fileWriter = [[DBHTMLWriter alloc] initWithHandle:fileHandleOut];
      if (fileTypeOut == DBFileFormatXLS)
        [fileWriter setFileFormat:DBFileFormatXLS];
      else
        [fileWriter setFileFormat:DBFileFormatHTML];
    }

  [fileWriter setLogger:logger];
  [fileWriter setWriteFieldsOrdered:([orderedWritingSelectIdent state] == NSOnState)];
  [fileWriter setStringEncoding: [defaults integerForKey: @"StringEncoding"]];

  
  selectIdentProgress = [[DBProgress alloc] init];
  [selectIdentProgress setLogger:logger];
  [selectIdentProgress setProgressIndicator: progIndSelectIdent];
  [selectIdentProgress setRemainingTimeField: fieldRTSelectIdent];
  [selectIdentProgress reset];

  NS_DURING
    [dbCsv queryIdentify :statement queryAll:([queryAllSelectIdentify state] == NSOnState) fromReader:csvReader toWriter:fileWriter withBatchSize:batchSize progressMonitor:selectIdentProgress];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER

  [csvReader release];
  [fileWriter release];
  [fileHandleOut closeFile];
  
  [selectIdentProgress release];
  selectIdentProgress = nil;
  [self performSelectorOnMainThread:@selector(resetSelectIdentUI:) withObject:self waitUntilDone:NO];
  [arp release];
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


/*  RETRIEVE  */

- (IBAction)showRetrieve:(id)sender
{
  [winRetrieve makeKeyAndOrderFront:self];
  [progIndRetrieve setIndeterminate:NO];
  [progIndRetrieve setDoubleValue:0];
}

- (IBAction)browseFileRetrieveIn:(id)sender
{
  NSOpenPanel *openPanel;
  
  openPanel = [NSOpenPanel openPanel];
  if ([openPanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [openPanel filename];
      [fieldFileRetrieveIn setStringValue:fileName];
    }
}

- (IBAction)browseFileRetrieveOut:(id)sender
{
  NSSavePanel *savePanel;
  NSArray *types;
  
  types = [NSArray arrayWithObjects:@"csv", @"html", @"xls", nil];  
  savePanel = [NSSavePanel savePanel];
  [savePanel setAllowedFileTypes:types];
  if ([savePanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [savePanel filename];
      [fieldFileRetrieveOut setStringValue:fileName];
    }
}

- (void)resetRetrieveUI:(id)arg
{
  [buttonRetrieveExec setEnabled:YES];
  [buttonRetrieveStop setEnabled:NO];
}

- (void)performRetrieve:(id)arg
{
  NSString       *statement;
  NSString       *filePathIn;
  NSString       *filePathOut;
  NSFileHandle   *fileHandleOut;
  NSFileManager  *fileManager;
  DBFileWriter   *fileWriter;
  DBCSVReader    *csvReader;
  NSString       *fileTypeOut;
  int            batchSize;
  NSString       *str;
  NSUserDefaults *defaults;
  NSAutoreleasePool *arp;

  arp = [NSAutoreleasePool new];
  defaults = [NSUserDefaults standardUserDefaults];

  statement = [fieldQueryRetrieve string];
  filePathIn = [fieldFileRetrieveIn stringValue];
  filePathOut = [fieldFileRetrieveOut stringValue];
  fileTypeOut = DBFileFormatCSV;
  if ([[[filePathOut pathExtension] lowercaseString] isEqualToString:@"html"])
    fileTypeOut = DBFileFormatHTML;
  else if ([[[filePathOut pathExtension] lowercaseString] isEqualToString:@"xls"])
    fileTypeOut = DBFileFormatXLS;
  
  batchSize = 0;
  switch ([[popupBatchSizeRetrieve selectedItem] tag])
    {
    case 1:
      batchSize = 1;
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
    case 6:
      batchSize = 500;
      break;
    case 7:
      batchSize = 1000;
      break;
    case 99:
      batchSize = -1;
      break;
    default:
      [logger log:LogStandard :@"[AppController executeRetrieve] unexpected batch size\n"];
    }
  [logger log:LogDebug :@"[AppController executeRetrieve] batch Size: %d\n", batchSize];
  
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
      [arp release];
      [self performSelectorOnMainThread:@selector(resetRetrieveUI:) withObject:self waitUntilDone:NO];
      return;
    }  

  fileHandleOut = [NSFileHandle fileHandleForWritingAtPath:filePathOut];
  if (fileHandleOut == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
      [csvReader release];
      [arp release];
      [self performSelectorOnMainThread:@selector(resetRetrieveUI:) withObject:self waitUntilDone:NO];
      return;
    }

  fileWriter = nil;
  if (fileTypeOut == DBFileFormatCSV)
    {
      fileWriter = [[DBCSVWriter alloc] initWithHandle:fileHandleOut];
      str = [defaults stringForKey:@"CSVWriteQualifier"];
      if (str)
	[(DBCSVWriter *)fileWriter setQualifier:str];
      str = [defaults stringForKey:@"CSVWriteSeparator"];
      if (str)
	[(DBCSVWriter *)fileWriter setSeparator:str];
      [(DBCSVWriter *)fileWriter setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
    }
  else if (fileTypeOut == DBFileFormatHTML || fileTypeOut == DBFileFormatXLS)
    {
      fileWriter = [[DBHTMLWriter alloc] initWithHandle:fileHandleOut];
      if (fileTypeOut == DBFileFormatXLS)
        [fileWriter setFileFormat:DBFileFormatXLS];
      else
        [fileWriter setFileFormat:DBFileFormatHTML];
    }

  [fileWriter setLogger:logger];
  [fileWriter setWriteFieldsOrdered:([orderedWritingRetrieve state] == NSOnState)];
  [fileWriter setStringEncoding: [defaults integerForKey: @"StringEncoding"]];

  
  retrieveProgress = [[DBProgress alloc] init];
  [retrieveProgress setLogger:logger];
  [retrieveProgress setProgressIndicator: progIndRetrieve];
  [retrieveProgress setRemainingTimeField: fieldRTRetrieve];
  [retrieveProgress reset];

  NS_DURING
    [dbCsv retrieve :statement fromReader:csvReader toWriter:fileWriter withBatchSize:batchSize progressMonitor:retrieveProgress];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER

  [csvReader release];
  [fileWriter release];
  [fileHandleOut closeFile];
  
  [retrieveProgress release];
  retrieveProgress = nil;
  [self performSelectorOnMainThread:@selector(resetRetrieveUI:) withObject:self waitUntilDone:NO];
  [arp release];
}

- (IBAction)executeRetrieve:(id)sender
{
  [buttonRetrieveExec setEnabled:NO];
  [buttonRetrieveStop setEnabled:YES];
  [NSThread detachNewThreadSelector:@selector(performRetrieve:) toTarget:self withObject:nil];
}


- (IBAction)stopRetrieve:(id)sender
{
  [retrieveProgress setShouldStop:YES];
}

/* GET UPDATED */

- (IBAction)showGetUpdated:(id)sender
{
  NSArray *objectNames;

  objectNames = [db sObjectNames];
  [logger log:LogStandard :@"[AppController showGetUpdated] Objects: %lu", (unsigned long)[objectNames count]];

  [popupObjectsGetUpdated removeAllItems];
  [popupObjectsGetUpdated addItemsWithTitles: objectNames];
    
  [winGetUpdated makeKeyAndOrderFront:self];
}

- (IBAction)browseFileGetUpdated:(id)sender
{
  NSSavePanel *savePanel;
  NSArray *types;

  types = [NSArray arrayWithObjects:@"csv", @"html", @"xls", nil];
  savePanel = [NSSavePanel savePanel];
  [savePanel setAllowedFileTypes:types];

  if ([savePanel runModal] == NSOKButton)
    {
      NSString *fileName;
    
      fileName = [savePanel filename];
      [fieldFileGetUpdated setStringValue:fileName];
    }
}

- (IBAction)executeGetUpdated:(id)sender
{
  NSString       *filePath;
  DBFileWriter   *writer;
  NSString       *whichObject;
  NSFileManager  *fileManager;
  NSFileHandle   *fileHandle;
  NSUserDefaults *defaults;
  NSString       *str;
  NSString       *fileType;
  NSDate         *startDate;
  NSDate         *endDate;

  defaults = [NSUserDefaults standardUserDefaults];
    
  filePath = [fieldFileGetUpdated stringValue];
  fileType = DBFileFormatCSV;
  if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"html"])
    fileType = DBFileFormatHTML;
  else if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"xls"])
    fileType = DBFileFormatXLS;
  
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

  writer = nil;
  if (fileType == DBFileFormatCSV)
    {
      writer = [[DBCSVWriter alloc] initWithHandle:fileHandle];
      [(DBCSVWriter *)writer setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
      str = [defaults stringForKey:@"CSVWriteQualifier"];
      if (str)
        [(DBCSVWriter *)writer setQualifier:str];
      str = [defaults stringForKey:@"CSVWriteSeparator"];
      if (str)
        [(DBCSVWriter *)writer setSeparator:str];
    }
  else if (fileType == DBFileFormatHTML || fileType == DBFileFormatXLS)
    {
      writer = [[DBHTMLWriter alloc] initWithHandle:fileHandle];
      if (fileType == DBFileFormatXLS)
        [writer setFileFormat:DBFileFormatXLS];
      else
        [writer setFileFormat:DBFileFormatHTML];
    }
  
  [writer setLogger:logger];
  [writer setStringEncoding: [defaults integerForKey: @"StringEncoding"]];

  whichObject = [[[popupObjectsGetUpdated selectedItem] title] retain];

  startDate = [NSDate date];
  endDate = [NSDate date];
  startDate = [startDate addTimeInterval:-30*24*3600];
  
  NS_DURING
    [dbCsv getUpdated:whichObject :startDate :endDate toWriter:writer progressMonitor:nil];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER

  [writer release];
  [fileHandle closeFile];
  [whichObject release];
}

/* GET DELETED */

- (IBAction)showGetDeleted:(id)sender
{
  NSArray *objectNames;

  objectNames = [db sObjectNames];
  [logger log:LogStandard :@"[AppController showGetDeleted] Objects: %lu", (unsigned long)[objectNames count]];

  [popupObjectsGetDeleted removeAllItems];
  [popupObjectsGetDeleted addItemsWithTitles: objectNames];
    
  [winGetDeleted makeKeyAndOrderFront:self];
}

- (IBAction)browseFileGetDeleted:(id)sender
{
  NSSavePanel *savePanel;
  NSArray *types;

  types = [NSArray arrayWithObjects:@"csv", @"html", @"xls", nil];
  savePanel = [NSSavePanel savePanel];
  [savePanel setAllowedFileTypes:types];

  if ([savePanel runModal] == NSOKButton)
    {
      NSString *fileName;
    
      fileName = [savePanel filename];
      [fieldFileGetDeleted setStringValue:fileName];
    }
}

- (IBAction)executeGetDeleted:(id)sender
{
  NSString       *filePath;
  DBFileWriter   *writer;
  NSString       *whichObject;
  NSFileManager  *fileManager;
  NSFileHandle   *fileHandle;
  NSUserDefaults *defaults;
  NSString       *str;
  NSString       *fileType;
  NSDate         *startDate;
  NSDate         *endDate;

  defaults = [NSUserDefaults standardUserDefaults];
    
  filePath = [fieldFileGetDeleted stringValue];
  fileType = DBFileFormatCSV;
  if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"html"])
    fileType = DBFileFormatHTML;
  else if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"xls"])
    fileType = DBFileFormatXLS;
  
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

  writer = nil;
  if (fileType == DBFileFormatCSV)
    {
      writer = [[DBCSVWriter alloc] initWithHandle:fileHandle];
      [(DBCSVWriter *)writer setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
      str = [defaults stringForKey:@"CSVWriteQualifier"];
      if (str)
        [(DBCSVWriter *)writer setQualifier:str];
      str = [defaults stringForKey:@"CSVWriteSeparator"];
      if (str)
        [(DBCSVWriter *)writer setSeparator:str];
    }
  else if (fileType == DBFileFormatHTML || fileType == DBFileFormatXLS)
    {
      writer = [[DBHTMLWriter alloc] initWithHandle:fileHandle];
      if (fileType == DBFileFormatXLS)
        [writer setFileFormat:DBFileFormatXLS];
      else
        [writer setFileFormat:DBFileFormatHTML];
    }
  
  [writer setLogger:logger];
  [writer setStringEncoding: [defaults integerForKey: @"StringEncoding"]];

  whichObject = [[[popupObjectsGetDeleted selectedItem] title] retain];

  startDate = [NSDate date];
  endDate = [NSDate date];
  startDate = [startDate addTimeInterval:-30*24*3600];
  
  NS_DURING
    [dbCsv getDeleted:whichObject :startDate :endDate toWriter:writer progressMonitor:nil];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER

  [writer release];
  [fileHandle closeFile];
  [whichObject release];
}

/* DESCRIBE */

- (IBAction)showDescribe:(id)sender
{
  NSArray *objectNames;

  objectNames = [db sObjectNames];
  [logger log:LogStandard :@"[AppController showDescribe] Objects: %lu", (unsigned long)[objectNames count]];

  [popupObjectsDescribe removeAllItems];
  [popupObjectsDescribe addItemsWithTitles: objectNames];
    
  [winDescribe makeKeyAndOrderFront:self];
}

- (IBAction)browseFileDescribe:(id)sender
{
  NSSavePanel *savePanel;
  NSArray *types;

  types = [NSArray arrayWithObjects:@"csv", @"html", @"xls", nil];
  savePanel = [NSSavePanel savePanel];
  [savePanel setAllowedFileTypes:types];

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
  DBFileWriter    *writer;
  NSString       *whichObject;
  NSFileManager  *fileManager;
  NSFileHandle   *fileHandle;
  NSUserDefaults *defaults;
  NSString       *str;
  NSString       *fileType;

  defaults = [NSUserDefaults standardUserDefaults];
    
  filePath = [fieldFileDescribe stringValue];
  fileType = DBFileFormatCSV;
  if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"html"])
    fileType = DBFileFormatHTML;
  else if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"xls"])
    fileType = DBFileFormatXLS;
  
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

  writer = nil;
  if (fileType == DBFileFormatCSV)
    {
      writer = [[DBCSVWriter alloc] initWithHandle:fileHandle];
      [(DBCSVWriter *)writer setLineBreakHandling:[defaults integerForKey:CSVWriteLineBreakHandling]];
      str = [defaults stringForKey:@"CSVWriteQualifier"];
      if (str)
        [(DBCSVWriter *)writer setQualifier:str];
      str = [defaults stringForKey:@"CSVWriteSeparator"];
      if (str)
        [(DBCSVWriter *)writer setSeparator:str];
    }
  else if (fileType == DBFileFormatHTML || fileType == DBFileFormatXLS)
    {
      writer = [[DBHTMLWriter alloc] initWithHandle:fileHandle];
      if (fileType == DBFileFormatXLS)
        [writer setFileFormat:DBFileFormatXLS];
      else
        [writer setFileFormat:DBFileFormatHTML];
    }
  
  [writer setLogger:logger];
  [writer setStringEncoding: [defaults integerForKey: @"StringEncoding"]];

  whichObject = [[[popupObjectsDescribe selectedItem] title] retain];
  
  NS_DURING
    [dbCsv describeSObject:whichObject toWriter:writer];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [self performSelectorOnMainThread:@selector(showException:) withObject:localException waitUntilDone:YES];
      }
  NS_ENDHANDLER

  [writer release];
  [fileHandle closeFile];
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
    {
      [arp release];
      return;
    }

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

  [self performSelectorOnMainThread:@selector(resetQuickDeleteUI:) withObject:self waitUntilDone:NO];
  [dbSoap release];
  [arp release];
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
  [arp release];
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

/* UNDELETE */

- (IBAction)showUnDelete:(id)sender
{
  [winUnDelete makeKeyAndOrderFront:self];
  [progIndUnDelete setIndeterminate:NO];
  [progIndUnDelete setDoubleValue:0];
}

- (IBAction)browseFileUnDelete:(id)sender
{
  NSOpenPanel *openPanel;
  
  openPanel = [NSOpenPanel openPanel];
//  [openPanel setRequiredFileType:@"csv"];
  if ([openPanel runModal] == NSOKButton)
    {
      NSString *fileName;
      
      fileName = [openPanel filename];
      [fieldFileUnDelete setStringValue:fileName];
    }
}

- (void)resetUnDeleteUI:(id)arg
{
  [buttonUnDeleteExec setEnabled:YES];
  [buttonUnDeleteStop setEnabled:NO];
}

- (void)performUnDelete:(id)arg
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
  filePath = [fieldFileUnDelete stringValue];
  resFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"results.csv"];
    
  reader = [[DBCSVReader alloc] initWithPath:filePath byParsingHeaders:YES withLogger:logger];
  str = [defaults stringForKey:@"CSVReadQualifier"];
  if (str)
    [reader setQualifier:str];
  str = [defaults stringForKey:@"CSVReadSeparator"];
  if (str)
    [reader setSeparator:str];
  /* no need to reparse the headers since they are not used, just skipped */

  unDeleteProgress = [[DBProgress alloc] init];
  [unDeleteProgress setProgressIndicator: progIndUnDelete];
  [unDeleteProgress setRemainingTimeField: fieldRTUnDelete];
  [unDeleteProgress setLogger:logger];
  [unDeleteProgress reset];

  results = nil;  
  NS_DURING
    results = [dbCsv undeleteFromReader:reader progressMonitor:unDeleteProgress];
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
  [unDeleteProgress release];
  unDeleteProgress = nil;
  [self performSelectorOnMainThread:@selector(resetUnDeleteUI:) withObject:self waitUntilDone:NO];
  [arp release];
}

- (IBAction)executeUnDelete:(id)sender
{
  [buttonUnDeleteExec setEnabled:NO];
  [buttonUnDeleteStop setEnabled:YES];
  [NSThread detachNewThreadSelector:@selector(performUnDelete:) toTarget:self withObject:nil];
}

- (IBAction)stopUnDelete:(id)sender
{
  [unDeleteProgress setShouldStop:YES];
}

/* OBJECT INSPECTOR */

- (IBAction)showObjectInspector:(id)sender
{
  [objInspector show];
}

@end
