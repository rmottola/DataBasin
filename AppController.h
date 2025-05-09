/* -*- mode: objc -*-
   Project: DataBasin

   Copyright (C) 2008-2025 Free Software Foundation

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
 
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
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
  IBOutlet NSTextField   *fieldOrgId;
  IBOutlet NSTextField   *fieldOrgName;
  IBOutlet NSTextField   *fieldSessionId;
  IBOutlet NSTextField   *fieldServerUrl;
  IBOutlet NSTextField   *fieldHost;
  IBOutlet NSTextField   *fieldPwdExpired;
  IBOutlet NSButton      *buttonSessionEditEnable;
  IBOutlet NSButton      *buttonSetSessionData;

  /* user and environment */
  IBOutlet NSWindow      *winUserInspector;

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

  /* query retrieve */
  IBOutlet NSWindow      *winRetrieve;
  IBOutlet NSTextView    *fieldQueryRetrieve;
  IBOutlet NSTextField   *fieldFileRetrieveIn;
  IBOutlet NSTextField   *fieldFileRetrieveOut;
  IBOutlet NSPopUpButton *popupBatchSizeRetrieve;
  IBOutlet NSProgressIndicator *progIndRetrieve;
  IBOutlet NSTextField   *fieldRTRetrieve;
  IBOutlet NSButton      *orderedWritingRetrieve;
  IBOutlet NSButton      *buttonRetrieveExec;
  IBOutlet NSButton      *buttonRetrieveStop;
  DBProgress *retrieveProgress;

  /* getUpdated */
  IBOutlet NSWindow      *winGetUpdated;
  IBOutlet NSTextField   *fieldFileGetUpdated;
  IBOutlet NSComboBox    *comboObjectsGetUpdated;
  IBOutlet NSButton      *buttonGetUpdatedExec;
  DBProgress *getUpdatedProgress;

  /* getDeleted */
  IBOutlet NSWindow      *winGetDeleted;
  IBOutlet NSTextField   *fieldFileGetDeleted;
  IBOutlet NSComboBox    *comboObjectsGetDeleted;
  IBOutlet NSButton      *buttonGetDeletedExec;
  DBProgress *getDeletedProgress;
  
  /* insert */
  IBOutlet NSWindow      *winInsert;
  IBOutlet NSTextField   *fieldFileInsert;
  IBOutlet NSComboBox    *comboObjectsInsert;
  IBOutlet NSProgressIndicator *progIndInsert;
  IBOutlet NSTextField   *fieldRTInsert;
  IBOutlet NSButton      *buttonInsertExec;
  IBOutlet NSButton      *buttonInsertStop;
  DBProgress *insertProgress;

  /* update */
  IBOutlet NSWindow      *winUpdate;
  IBOutlet NSTextField   *fieldFileUpdate;
  IBOutlet NSComboBox    *comboObjectsUpdate;
  IBOutlet NSProgressIndicator *progIndUpdate;
  IBOutlet NSTextField   *fieldRTUpdate;
  IBOutlet NSButton      *buttonUpdateExec;
  IBOutlet NSButton      *buttonUpdateStop;
  DBProgress *updateProgress;

  /* describe */
  IBOutlet NSWindow      *winDescribe;
  IBOutlet NSTextField   *fieldFileDescribe;
  IBOutlet NSComboBox    *comboObjectsDescribe;
  
  /* quick delete */
  IBOutlet NSWindow      *winQuickDelete;
  IBOutlet NSTextField   *fieldObjectIdQd;
  IBOutlet NSTextField   *fieldStatusQd;
  IBOutlet NSButton      *buttonQuickDeleteExec;
  
  /* mass delete */
  IBOutlet NSWindow      *winDelete;
  IBOutlet NSTextField   *fieldFileDelete;
  IBOutlet NSButton      *checkSkipFirstLine;
  IBOutlet NSButton      *buttonDeleteExec;
  IBOutlet NSButton      *buttonDeleteStop;
  IBOutlet NSTextField   *fieldRTDelete;
  IBOutlet NSProgressIndicator *progIndDelete;
  DBProgress *deleteProgress;

  /* mass undelete */
  IBOutlet NSWindow      *winUnDelete;
  IBOutlet NSTextField   *fieldFileUnDelete;
  IBOutlet NSButton      *buttonUnDeleteExec;
  IBOutlet NSButton      *buttonUnDeleteStop;
  IBOutlet NSTextField   *fieldRTUnDelete;
  IBOutlet NSProgressIndicator *progIndUnDelete;
  DBProgress *unDeleteProgress;

  
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

/* reload defaults that are not queryied dynamically and need be reloaded on their change */
- (void)reloadDefaults;

- (void)setUserInfo:(NSDictionary *)userInfoDict;

- (IBAction)showPrefPanel:(id)sender;

- (IBAction)showLogin:(id)sender;
- (IBAction)usernameFieldAction:(id)sender;
- (IBAction)doLogin:(id)sender;

- (IBAction)showSessionInspector:(id)sender;
- (IBAction)setEnableSessionEditing:(id)sender;
- (IBAction)setSessionData:(id)sender;

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

- (IBAction)showRetrieve:(id)sender;
- (IBAction)browseFileRetrieveIn:(id)sender;
- (IBAction)browseFileRetrieveOut:(id)sender;
- (IBAction)executeRetrieve:(id)sender;
- (IBAction)stopRetrieve:(id)sender;

- (IBAction)showGetUpdated:(id)sender;
- (IBAction)browseFileGetUpdated:(id)sender;
- (IBAction)executeGetUpdated:(id)sender;

- (IBAction)showGetDeleted:(id)sender;
- (IBAction)browseFileGetDeleted:(id)sender;
- (IBAction)executeGetDeleted:(id)sender;

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

- (IBAction)showUnDelete:(id)sender;
- (IBAction)browseFileUnDelete:(id)sender;
- (IBAction)executeUnDelete:(id)sender;
- (IBAction)stopUnDelete:(id)sender;

- (IBAction)showObjectInspector:(id)sender;

@end
