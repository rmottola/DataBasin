/* 
   Project: DataBasin

   Copyright (C) 2008-2011 Free Software Foundation

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
#import "DBCVSWriter.h"
#import "DBCVSReader.h"

#define DB_ENVIRONMENT_PRODUCTION 0
#define DB_ENVIRONMENT_SANDBOX    1

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
    }
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

- (void)awakeFromNib
{
#if defined(__APPLE__) && (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
  [popupStrEncoding setAutoenablesItems: NO];
  [[popupStrEncoding itemAtIndex: 1] setEnabled: NO];
#endif
  
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

- (IBAction)showPrefPanel:(id)sender
{
  NSUserDefaults *defaults;
  int index;

  defaults = [NSUserDefaults standardUserDefaults];
  
  index = 0;
  switch([[defaults valueForKey: @"StringEncoding"] intValue])
    {
      case NSUTF8StringEncoding:
        index = 0;
        break;
      case NSUTF16StringEncoding:
        index = 1;
        break;
      case NSISOLatin1StringEncoding:
        index = 2;
        break;
      case NSWindowsCP1252StringEncoding:
        index = 3;
        break;
    }
  [popupStrEncoding selectItemAtIndex: index];
  [prefPanel makeKeyAndOrderFront: sender];
}

- (IBAction)prefPanelCancel:(id)sender
{
  [prefPanel performClose: nil];
}

- (IBAction)prefPanelOk:(id)sender
{
  NSStringEncoding selectedEncoding;
  NSUserDefaults *defaults;

  defaults = [NSUserDefaults standardUserDefaults];
  
  selectedEncoding = NSUTF8StringEncoding;
  switch([popupStrEncoding indexOfSelectedItem])
    {
      case 0: selectedEncoding = NSUTF8StringEncoding;
        break;
      case 1: selectedEncoding = NSUTF16StringEncoding;
        break;
      case 2: selectedEncoding = NSISOLatin1StringEncoding;
        break;
      case 3: selectedEncoding = NSWindowsCP1252StringEncoding;
        break;
    }
    
  [defaults setObject:[NSNumber numberWithInt: selectedEncoding] forKey: @"StringEncoding"];
  [prefPanel performClose: nil];
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


/* LOGIN */

- (IBAction)showLogin:(id)sender
{
  [winLogin makeKeyAndOrderFront:self];
}

- (IBAction)doLogin:(id)sender
{
  NSString *userName;
  NSString *password;
  NSString *token;
  NSString *urlStr;
  NSURL    *url;
  NSDictionary *uInfo;
  
  userName = [fieldUserName stringValue];
  password = [fieldPassword stringValue];
  token = [fieldToken stringValue];

  /* if present, we append the security token to the password */
  if (token != nil)
    password = [password stringByAppendingString:token];
    
  db = [[DBSoap alloc] init];
  
  if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_PRODUCTION)
    urlStr = @"http://www.salesforce.com/services/Soap/u/20.0";
  else if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_SANDBOX)
    urlStr = @"http://test.salesforce.com/services/Soap/u/20.0";
  NSLog(@"Url: %@", urlStr);  
  url = [NSURL URLWithString:urlStr];
  
  NS_DURING
    [db login :url :userName :password];
    
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
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
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
  
  statement = [fieldQuerySelect string];
  NSLog(@"%@", statement);
  filePath = [fieldFileSelect stringValue];
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
  
  cvsWriter = [[DBCVSWriter alloc] initWithHandle:fileHandle];
  
  [db query :statement queryAll:([queryAllSelect state] == NSOnState) toWriter:cvsWriter];
    
  [cvsWriter release];
  [fileHandle closeFile];
}

/* INSERT */


- (IBAction)showInsert:(id)sender
{
  NSArray *objectNames;

  objectNames = [db sObjectNames];
  [popupObjectsInsert removeAllItems];
  [popupObjectsInsert addItemsWithTitles: objectNames];

  [winInsert makeKeyAndOrderFront:self];
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
  NSString      *filePath;
  DBCVSReader   *reader;
  NSString      *intoWhichObject;
  
  filePath = [fieldFileInsert stringValue];
  NSLog(@"%@", filePath);
  
  intoWhichObject = [[[popupObjectsInsert selectedItem] title] retain];
  NSLog(@"object: %@", intoWhichObject);
  
  reader = [[DBCVSReader alloc] initWithPath:filePath];
  
  NS_DURING
    [db create:intoWhichObject fromReader:reader];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
  
  [reader release];
  [intoWhichObject release];
}

/* UPDATE */


- (IBAction)showUpdate:(id)sender
{
  NSArray      *objectsArray;
  
  objectsArray  = nil;
  NS_DURING
    objectsArray = [db describeGlobal];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
  [popupObjectsUpdate removeAllItems];
  [popupObjectsUpdate addItemsWithTitles: objectsArray];
    
  [winUpdate makeKeyAndOrderFront:self];
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
  NSString      *filePath;
  DBCVSReader   *reader;
  NSString      *whichObject;
  
  filePath = [fieldFileUpdate stringValue];
  NSLog(@"%@", filePath);
  
  whichObject = [[[popupObjectsUpdate selectedItem] title] retain];
  NSLog(@"object: %@", whichObject);
  
  reader = [[DBCVSReader alloc] initWithPath:filePath];
  
  NS_DURING
    [db update:whichObject fromReader:reader];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
    
  [reader release];
  [whichObject release];
}

/*  SELECT IDENTIFY */

- (IBAction)showSelectIdentify:(id)sender
{
  [winSelectIdentify makeKeyAndOrderFront:self];
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
  NSFileHandle  *fileHandleIn;
  NSString      *filePathOut;
  NSFileHandle  *fileHandleOut;
  NSFileManager *fileManager;
  DBCVSWriter   *cvsWriter;
  DBCVSReader   *cvsReader;
  NSString      *identifyField;
  
  statement = [fieldQuerySelectIdentify string];
  NSLog(@"%@", statement);
  filePathIn = [fieldFileSelectIdentifyIn stringValue];
  NSLog(@"%@", filePathIn);
  filePathOut = [fieldFileSelectIdentifyOut stringValue];
  NSLog(@"%@", filePathOut);
  identifyField = [fieldFieldSelectIdentify stringValue];
  NSLog(@"%@", identifyField);
  
  fileManager = [NSFileManager defaultManager];
  if ([fileManager createFileAtPath:filePathIn contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
      return;
    }  

  fileHandleIn = [NSFileHandle fileHandleForReadingAtPath:filePathIn];
  if (fileHandleIn == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
    }

  cvsReader = [[DBCVSReader alloc] initWithHandle:fileHandleIn];

  if ([fileManager createFileAtPath:filePathOut contents:nil attributes:nil] == NO)
    {
      NSRunAlertPanel(@"Attention", @"Could not create File.", @"Ok", nil, nil);
      return;
    }  

  fileHandleOut = [NSFileHandle fileHandleForWritingAtPath:filePathOut];
  if (fileHandleOut == nil)
    {
      NSRunAlertPanel(@"Attention", @"Cannot create File.", @"Ok", nil, nil);
    }
  
  cvsWriter = [[DBCVSWriter alloc] initWithHandle:fileHandleOut];
  
  //  [db query :statement queryAll:([queryAllSelectIdentify state] == NSOnState) toWriter:cvsWriter];

  [cvsReader release];
  [fileHandleIn closeFile];
  
  [cvsWriter release];
  [fileHandleOut closeFile];
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
  [writer setStringEncoding: [[defaults valueForKey: @"StringEncoding"] intValue]];
  
  whichObject = [[[popupObjectsDescribe selectedItem] title] retain];
  NSLog(@"object: %@", whichObject);
  
  NS_DURING
    [db describeSObject:whichObject toWriter:writer];
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
    resultArray = [db delete: idArray];
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
  NSString      *filePath;
  DBCVSReader   *reader;
  
  filePath = [fieldFileDelete stringValue];
  NSLog(@"%@", filePath);
    
  reader = [[DBCVSReader alloc] initWithPath:filePath byParsingHeaders:([checkSkipFirstLine state]==NSOnState)];  
  
  NS_DURING
    [db deleteFromReader:reader];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER

  [reader release];
}

/* OBJECT INSPECTOR */

- (IBAction)showObjectInspector:(id)sender
{
  [objInspector setSoapHandler: db];
  [objInspector show];
}

@end
