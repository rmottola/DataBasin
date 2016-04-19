/* -*- mode: objc -*-
   Project: DataBasin

   Copyright (C) 2008-2016 Free Software Foundation

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
 
#import <AppKit/AppKit.h>

#import "DBObjectInspector.h"

@class DBSoap;
@class DBSoapCSV;
@class DBLogger;
@class Preferences;
@class DBProgress;

@interface AppController : NSObject
{
  DBSoap    *db;
  DBSoapCSV *dbCsv;
  DBLogger  *logger;
  NSMutableDictionary *loginDict;
  
  Preferences *preferences;

  /* fault panel */
  IBOutlet NSPanel    *faultPanel;
  IBOutlet NSTextView *faultTextView;
  
  /* login */
  IBOutlet NSWindow      *winLogin;
  IBOutlet NSTextField   *fieldUserName;
  IBOutlet NSTextField   *fieldPassword;
  IBOutlet NSTextField   *fieldToken;
  IBOutlet NSPopUpButton *popupEnvironment;
  IBOutlet NSImageView   *loginStatus;
  
  /* session status */
  IBOutlet NSWindow      *winSessionInspector;
  IBOutlet NSTextField   *fieldSessionId;
  IBOutlet NSTextField   *fieldServerUrl;
  IBOutlet NSTextField   *fieldPwdExpired;

  /* user and environment */
  IBOutlet NSWindow      *winUserInspector;
  IBOutlet NSTextField   *fieldOrgId;
  IBOutlet NSTextField   *fieldOrgName;
  IBOutlet NSTextField   *fieldUserNameInsp;
  IBOutlet NSTextField   *fieldUserFullName;
  IBOutlet NSTextField   *fieldUserEmail;
  IBOutlet NSTextField   *fieldUserId;
  IBOutlet NSTextField   *fieldProfileId;
  IBOutlet NSTextField   *fieldRoleId;

  /* query */
  IBOutlet NSWindow      *winSelect;
  IBOutlet NSTextView    *fieldQuerySelect;
  IBOutlet NSTextField   *fieldFileSelect;
  IBOutlet NSButton      *queryAllSelect;
  IBOutlet NSProgressIndicator *progIndSelect;
  IBOutlet NSTextField   *fieldRTSelect;
  IBOutlet NSButton      *orderedWritingSelect;
  IBOutlet NSButton      *buttonSelectExec;
  IBOutlet NSButton      *buttonSelectStop;
  DBProgress *selectProgress;

  /* query identify */
  IBOutlet NSWindow      *winSelectIdentify;
  IBOutlet NSTextView    *fieldQuerySelectIdentify;
  IBOutlet NSTextField   *fieldFileSelectIdentifyIn;
  IBOutlet NSTextField   *fieldFileSelectIdentifyOut;
  IBOutlet NSButton      *queryAllSelectIdentify;
  IBOutlet NSPopUpButton *popupBatchSizeIdentify;
  IBOutlet NSProgressIndicator *progIndSelectIdent;
  IBOutlet NSTextField   *fieldRTSelectIdent;
  IBOutlet NSButton      *orderedWritingSelectIdent;
  IBOutlet NSButton      *buttonSelectIdentExec;
  IBOutlet NSButton      *buttonSelectIdentStop;
  DBProgress *selectIdentProgress;
  
  /* insert */
  IBOutlet NSWindow      *winInsert;
  IBOutlet NSTextField   *fieldFileInsert;
  IBOutlet NSPopUpButton *popupObjectsInsert;
  IBOutlet NSProgressIndicator *progIndInsert;
  IBOutlet NSTextField   *fieldRTInsert;
  IBOutlet NSButton      *buttonInsertExec;
  IBOutlet NSButton      *buttonInsertStop;
  DBProgress *insertProgress;

  /* update */
  IBOutlet NSWindow      *winUpdate;
  IBOutlet NSTextField   *fieldFileUpdate;
  IBOutlet NSPopUpButton *popupObjectsUpdate;
  IBOutlet NSProgressIndicator *progIndUpdate;
  IBOutlet NSTextField   *fieldRTUpdate;
  IBOutlet NSButton      *buttonUpdateExec;
  IBOutlet NSButton      *buttonUpdateStop;
  DBProgress *updateProgress;

  /* describe */
  IBOutlet NSWindow      *winDescribe;
  IBOutlet NSTextField   *fieldFileDescribe;
  IBOutlet NSPopUpButton *popupObjectsDescribe;
  
  /* quick delete */
  IBOutlet NSWindow      *winQuickDelete;
  IBOutlet NSTextField   *fieldObjectIdQd;
  IBOutlet NSTextField   *fieldStatusQd;
  IBOutlet NSProgressIndicator *progIndDelete;
  IBOutlet NSTextField   *fieldRTDelete;  
  IBOutlet NSButton      *buttonQuickDeleteExec;
  
  /* mass delete */
  IBOutlet NSWindow      *winDelete;
  IBOutlet NSTextField   *fieldFileDelete;
  IBOutlet NSButton      *checkSkipFirstLine;
  IBOutlet NSButton      *buttonDeleteExec;
  IBOutlet NSButton      *buttonDeleteStop;
  DBProgress *deleteProgress;
  
  /* object inspector */
  DBObjectInspector *objInspector;
}

- (id)init;
- (void)dealloc;

- (void)awakeFromNib;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif;
- (BOOL)applicationShouldTerminate:(id)sender;
- (void)applicationWillTerminate:(NSNotification *)aNotif;
- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName;

/* reload defaults that are not queryied dymanically and need be reloaded on their change */
- (void)reloadDefaults;

- (IBAction)showPrefPanel:(id)sender;

- (IBAction)showLogin:(id)sender;
- (IBAction)usernameFieldAction:(id)sender;
- (IBAction)doLogin:(id)sender;

- (IBAction)showSessionInspector:(id)sender;
- (IBAction)showUserInspector:(id)sender;
- (IBAction)showLog:(id)sender;

- (IBAction)runDescribeGlobal:(id)sender;

- (IBAction)showSelect:(id)sender;
- (IBAction)browseFileSelect:(id)sender;
- (IBAction)executeSelect:(id)sender;
- (IBAction)stopSelect:(id)sender;

- (IBAction)showSelectIdentify:(id)sender;
- (IBAction)browseFileSelectIdentifyIn:(id)sender;
- (IBAction)browseFileSelectIdentifyOut:(id)sender;
- (IBAction)executeSelectIdentify:(id)sender;
- (IBAction)stopSelectIdentify:(id)sender;

- (IBAction)showQuickDelete:(id)sender;
- (IBAction)quickDelete:(id)sender;

- (IBAction)showInsert:(id)sender;
- (IBAction)browseFileInsert:(id)sender;
- (IBAction)executeInsert:(id)sender;
- (IBAction)stopInsert:(id)sender;

- (IBAction)showUpdate:(id)sender;
- (IBAction)browseFileUpdate:(id)sender;
- (IBAction)executeUpdate:(id)sender;
- (IBAction)stopUpdate:(id)sender;

- (IBAction)showDescribe:(id)sender;
- (IBAction)browseFileDescribe:(id)sender;
- (IBAction)executeDescribe:(id)sender;

- (IBAction)showDelete:(id)sender;
- (IBAction)browseFileDelete:(id)sender;
- (IBAction)executeDelete:(id)sender;
- (IBAction)stopDelete:(id)sender;

- (IBAction)showObjectInspector:(id)sender;

@end
