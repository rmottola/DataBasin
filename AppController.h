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
 
#import <AppKit/AppKit.h>

#import "DBSoap.h"

@interface AppController : NSObject
{
  DBSoap   *db;

  /* fault panel */
  IBOutlet NSPanel    *faultPanel;
  IBOutlet NSTextView *faultTextView;
  
  /* login */
  IBOutlet NSWindow      *winLogin;
  IBOutlet NSTextField   *fieldUserName;
  IBOutlet NSTextField   *fieldPassword;
  IBOutlet NSTextField   *fieldToken;
  IBOutlet NSPopUpButton *popupEnvironment;
  
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
  
  /* insert */
  IBOutlet NSWindow      *winInsert;
  IBOutlet NSTextField   *fieldFileInsert;
  IBOutlet NSPopUpButton *popupObjects;
  
  /* quick delete */
  IBOutlet NSWindow      *winQuickDelete;
  IBOutlet NSTextField   *fieldObjectIdQd;
  IBOutlet NSTextField   *fieldStatusQd;
  
  /* mass delete */
  IBOutlet NSWindow      *winDelete;
  IBOutlet NSTextField   *fieldFileDelete;
  IBOutlet NSButton      *checkSkipFirstLine;
}

+ (void)initialize;

- (id)init;
- (void)dealloc;

- (void)awakeFromNib;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif;
- (BOOL)applicationShouldTerminate:(id)sender;
- (void)applicationWillTerminate:(NSNotification *)aNotif;
- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName;

- (IBAction)showPrefPanel:(id)sender;

- (IBAction)showLogin:(id)sender;
- (IBAction)doLogin:(id)sender;

- (IBAction)showSessionInspector:(id)sender;
- (IBAction)showUserInspector:(id)sender;

- (IBAction)showSelect:(id)sender;
- (IBAction)browseFileSelect:(id)sender;
- (IBAction)executeSelect:(id)sender;

- (IBAction)showQuickDelete:(id)sender;
- (IBAction)quickDelete:(id)sender;

- (IBAction)showInsert:(id)sender;
- (IBAction)browseFileInsert:(id)sender;
- (IBAction)executeInsert:(id)sender;

- (IBAction)showDelete:(id)sender;
- (IBAction)browseFileDelete:(id)sender;
- (IBAction)executeDelete:(id)sender;

@end
