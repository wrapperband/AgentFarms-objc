#  Script Papers
#
#  Copyright (C) 2002 Stefan Urbanek
#
#  Written by:	Stefan Urbanek
#  Date: 2003 Apr 26
#
#  This file is part of the AgentFarms
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Library General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Library General Public License for more details.
#
#  You should have received a copy of the GNU Library General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA
#

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME     = LatticeView
PACKAGE_NAME = LatticeView

ScriptPapers_APPLICATION_ICON =
LatticeView_MAIN_MODEL_FILE  = Main.gorm

############################################################################
# ObjC files

LatticeView_OBJC_FILES= \
        AppController.m \
        main.m 

############################################################################
# Resource files

LatticeView_RESOURCE_FILES= \
        Main.gorm 

ADDITIONAL_OBJCFLAGS = -Wno-import
ADDITIONAL_GUI_LIBS +=  -lFarmsData -lFarmsFarmer

############################################################################

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
