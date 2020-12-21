#
# GNUmakefile - Generated by ProjectCenter
#
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

#
# Application
#
VERSION = 1.1 S
PACKAGE_NAME = DataBasin
APP_NAME = DataBasin
DataBasin_APPLICATION_ICON = 


#
# Libraries
#
DataBasin_LIBRARIES_DEPEND_UPON += -lWebServices -lDataBasinKit 

#
# Resource files
#
DataBasin_RESOURCE_FILES = \
Resources/DataBasin.gorm \
Resources/ObjectInspector.gorm \
Resources/Log.gorm \
Resources/Preferences.gorm \
Resources/butt_green_16.tif \
Resources/butt_red_16.tif \
Resources/stop_icon_15.tiff 


#
# Header files
#
DataBasin_HEADER_FILES = \
AppController.h \
DBObjectInspector.h \
DBLogger.h \
DBProgress.h \
Preferences.h \
DBTextFormatter.h

#
# Objective-C Class files
#
DataBasin_OBJC_FILES = \
AppController.m \
DBObjectInspector.m \
DBLogger.m \
DBProgress.m \
Preferences.m \
DBTextFormatter.m

#
# Other sources
#
DataBasin_OBJC_FILES += \
main.m 

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
