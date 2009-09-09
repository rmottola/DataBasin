/* 
   Project: DataBasin

   Copyright (C) 2008-2009 Free Software Foundation

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
  [[NSApp mainMenu] setTitle:@"DataBasin"];
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

- (void)showPrefPanel:(id)sender
{
}

/* SESSION INSPECTOR */

- (IBAction)showSessionInspector:(id)sender
{
  [winSessionInspector makeKeyAndOrderFront:self];
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
  
  userName = [fieldUserName stringValue];
  password = [fieldPassword stringValue];
  token = [fieldToken stringValue];

  /* if present, we append the security token to the password */
  if (token != nil)
    password = [password stringByAppendingString:token];
    
  db = [[DBSoap alloc] init];
  
  if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_PRODUCTION)
    urlStr = @"http://www.salesforce.com/services/Soap/u/8.0";
  else if ([popupEnvironment indexOfSelectedItem] == DB_ENVIRONMENT_SANDBOX)
    urlStr = @"http://test.salesforce.com/services/Soap/u/8.0";
  NSLog(@"Url: %@", urlStr);  
  url = [NSURL URLWithString:urlStr];
  
  NS_DURING
    [db login :url :userName :password];
    [fieldSessionId setStringValue:[db sessionId]];
    [fieldServerUrl setStringValue:[db serverUrl]];
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
  
  [db query :statement toWriter:cvsWriter];
  
  [cvsWriter release];
  [fileHandle closeFile];
}

/* INSERT */


- (IBAction)showInsert:(id)sender
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
  [popupObjects removeAllItems];
  [popupObjects addItemsWithTitles: objectsArray];

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
  
  intoWhichObject = [[[popupObjects selectedItem] title] retain];
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

/* QUICK DELETE */

- (IBAction)showQuickDelete:(id)sender
{
  [winQuickDelete makeKeyAndOrderFront:self];
}


- (IBAction)quickDelete:(id)sender
{
  NSString  *objectId;
  NSArray   *idArray;
  
  objectId = [fieldObjectIdQd stringValue];
  
  if (objectId == nil)
    return;
  
  idArray = [NSArray arrayWithObject:objectId];
  
  NS_DURING
    [db delete: idArray];
  NS_HANDLER
    if ([[localException name] hasPrefix:@"DB"])
      {
        [faultTextView setString:[localException reason]];
        [faultPanel makeKeyAndOrderFront:nil];
      }
  NS_ENDHANDLER
}

@end
