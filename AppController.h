/* 
   Project: DataBasin

   Copyright (C) 2008 Free Software Foundation

   Author: Riccardo Mottola,,,

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

  /* login*/
  IBOutlet NSTextField *fieldUserName;
  IBOutlet NSTextField *fieldPassword;
  IBOutlet NSTextField *fieldToken;
  
  /* query */
  IBOutlet NSWindow    *winSelect;
  IBOutlet NSTextView  *fieldQuerySelect;
  IBOutlet NSTextField *fieldFileSelect;
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
- (IBAction)doLogin:(id)sender;

- (IBAction)showSelect:(id)sender;
- (IBAction)browseFileSelect:(id)sender;
- (IBAction)executeSelect:(id)sender;

@end
