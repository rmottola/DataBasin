#
# GNUmakefile - Generated by ProjectCenter
#
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

#
# Application
#
VERSION = 0.6
PACKAGE_NAME = DataBasin
APP_NAME = DataBasin
DataBasin_APPLICATION_ICON = 


#
# Libraries
#
DataBasin_LIBRARIES_DEPEND_UPON += -lWebServices 

#
# Resource files
#
DataBasin_RESOURCE_FILES = \
Resources/DataBasin.gorm \
Resources/ObjectInspector.gorm \
Resources/Log.gorm 


#
# Header files
#
DataBasin_HEADER_FILES = \
AppController.h \
DBSoap.h \
DBCVSWriter.h \
DBCVSReader.h \
DBSObject.h \
DBObjectInspector.h \
DBSoapCSV.h \
DBLogger.h \
DBProgressProtocol.h \
DBProgress.h

#
# Class files
#
DataBasin_OBJC_FILES = \
AppController.m \
DBSoap.m \
DBCVSWriter.m \
DBCVSReader.m \
DBSObject.m \
DBObjectInspector.m \
DBSoapCSV.m \
DBLogger.m \
DBProgress.m

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
