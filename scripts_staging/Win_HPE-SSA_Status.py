#!/usr/bin/python3
#
#.SYNOPSIS
#   HPE SmartArray Status
#
#.DESCRIPTION
#   Checks the status of RAID array(s) on HPE servers with Smart Array controllers - Requires SSACLI
#
#.OUTPUTS
#   Exit Code: 0 = Pass, 1 = Informational, 2 = Warning, 3 = Error
#
#.EXAMPLE
#  HPESmartArrayStatus()
#
#.NOTES
#   v1.0 12/5/2023 ConvexSERV
#   Requires SSACLI to be installed on the server. Will return an error if it's not installed.
#

import platform
import subprocess
import sys
import os

#=========================================#
#              Declarations               #
#=========================================#

#Declare SSA Command
SSACmd = ""

#Declare Data Structure for Controller Config/Status
hpssa_config = {
    "controllers": {
        #'model': "", # - Controller Model
        #'slot': "",  # - Controller Slot # (Address) [key]
        #'embedded': "",  # - Controller is Embedded (bool)
        #'sn': "",  # - Controller Serial Number
        #'cages': { #Cages can be renamed? Ex. "Gen8 ServBP 3x6  at Port 2I, Box 1, OK", Typical "Internal Drive Cage at Port 1I, Box 1, OK"
            #'internal': "",  # - Controller Cage is internal (bool)
            #'port': "",  # - Controller Cage Port [key]+
            #'box': "",  # - Controller Box Port [key]+
            #'status': "",  # - Controller Cage Status
        #}
        # 'arrays': { #  # - Arrays contain logical drives and physical drives - (3 leading spaces)
            # 'name': "",  # - Array Name [key]
            # 'media': "",  # - Array Media - Ex. "Solid State SATA", "SATA", "SAS", "Solid State SAS", "NVME?"
            # 'unused_space': "",  # - Free Space (not configured)
            # 'unused_space_unit': '',  # - Free Space Unit (MB,GB,TB,PB)
            # 'logical_drives': {  # - (6 leading spaces)
                # 'number': "",  # - Logical Drive Number [key]
                # 'capacity_num': "",  # - Logical Drive Capacity (just the number (decimal))
                # 'capacity_unit': "",  # - Logical Drive Unit of Capacity (KB, MB, GB, TB, PB)
                # 'raid_level': "",  # - RAID Level (0 = Stripe, 1 = Mirror, 5 = Parity Stripe, 6 = Double Parity, 1+0 = Stripe of Mirrors)
                # 'status': "",  # - Logical Drive Status
            # }
            # 'physical_drives': { # - (6 leading spaces)
                # 'address': "",  # - Drive Port:Box:Bay [key]
                # 'port': "",  # - Drive Port
                # 'box': "",  # - Drive Box
                # 'bay': "",  # - Drive Bay
                #  'type': "",  # - Drive Type
                # 'capacity_num': "",  # - Physical Drive Capacity (just the number (decimal))
                # 'capacity_unit': "",  # - Physical Drive Unit of Capacity (KB, MB, GB, TB, PB)
                # 'status': "",  # - Physical Drive Status
                #  'spare': ""  # - Physical Drive Spare Status (Is drive assigned as a spare?)
            # }
        # }
        # 'enclosures': { # - (3 leading spaces)
            # 'name': "",  # - Enclosure Name - Ex. "SEP" - Not sure what it is, capture anyway
            # 'vendor_id': "",  # - Enclosure Vendor ID
            # 'model': "",  # - Enclosure Model
            # 'device_num': "", # - Enclosure Device Number? - Not sure what it is, capture anyway
            # 'port': "",  # - Enclosure Port [key]+
            # 'box': "",  # - Enclosure Box [key]+
            # 'wwid': "",  # - Enclosure WWID - Serial?
        # }
        # 'expanders': { # - (3 leading spaces)
            # 'device_num': "",  # - Expander Device Number? - Not sure what it is, capture anyway
            # 'port': "",  # - Enclosure Port [key]+
            # 'box': "",  # - Enclosure Box [key]+
            # 'wwid': "",  # - Enclosure WWID - Serial?
        # }
        # 'devices': { # -  (3 leading spaces)
            # 'name': "",  # - Device Name? - Ex. "SEP" - Not sure what it is, capture anyway
            # 'vendor_id': "",  # - Device Vendor ID
            # 'model': "",  # - Device Model
            # 'device_num': "", # - Device Number? - Not sure what it is, capture anyway
            # 'wwid': "", -  # - Device WWID - Serial? [key]
        # }
        #'status': {
            #"ctrl": "",  # - Controller Status
            #"cache": "",  # - Cache Status
            #"batt": ""  # - Battery/Capacitor Status
        #}
    }
}

#=========================================#
# Capture HPE SSA Config - SSAConfigAll[] #
#=========================================#

#Detect OS, Locate the HPSSA Command
platform = platform.system()

if platform == 'Linux':
        if os.path.exists('/usr/local/bin/hpssacli'):
          SSACmd = '/usr/local/bin/hpssacli'

else:
     #'Windows': # Path variables Use "r" (raw string) before the path to correct for backslashes in the path
        if os.path.exists(r"C:\Tools\Vendors\HPE\ssacli.exe"):
            SSACmd = r"C:\Tools\Vendors\HPE\ssacli.exe"
        elif os.path.exists(r"C:\Program Files\Smart Storage Administrator\ssacli\bin\ssacli.exe"):
            SSACmd = r"C:\Program Files\Smart Storage Administrator\ssacli\bin\ssacli.exe"
        elif os.path.exists(r"C:\Program Files (x86)\Smart Storage Administrator\ssacli\bin\ssacli.exe"):
            SSACmd = r"C:\Program Files (x86)\Smart Storage Administrator\ssacli\bin\ssacli.exe"
        elif os.path.exists(r"C:\Program Files (x86)\hp\hpssacli\bin\hpssacli.exe"):
            SSACmd = r"C:\Program Files (x86)\hp\hpssacli\bin\hpssacli.exe"
        elif os.path.exists(r"C:\Program Files\hp\hpssacli\bin\hpssacli.exe"):
            SSACmd = r"C:\Program Files\hp\hpssacli\bin\hpssacli.exe"
        elif os.path.exists(r"C:\Tools\Vendors\HPE\hpssacli.exe"):
            SSACmd = r"C:\Tools\Vendors\HPE\hpssacli.exe"

#Exit and Return Error Status if HPSSA Command is not found - Commented out while we use test files
if SSACmd == "":
    sys.stdout.write('HPASSA Command was not found in any of the configured paths.')
    sys.exit(3)

#Capture Output of HPSSA Config and store it - Commented out while we use test files
try:
    SSAConfigAll = []
    with subprocess.Popen([SSACmd, "ctrl", "all", "show", "config"], stdout=subprocess.PIPE,
        bufsize=1, universal_newlines=True) as SSACmdOutput:
            for line in SSACmdOutput.stdout:
                SSAConfigAll.append(line)
except subprocess.CalledProcessError as e:
    sys.stdout.write(f'Command {e.cmd} failed with error {e.returncode}')
    sys.exit(3)

#=======================================#
# Parse HPE SSA Config - SSAConfigAll[] #
#=======================================#

# Blank Line Counter
bl_count = 0
for config_line in SSAConfigAll:

    #Remove NewLine Characters
    config_line = config_line.replace("\n", "")

    #sys.stdout.write(config_line)
    if config_line == "" or config_line == '\n' or config_line == " ":
        bl_count = bl_count + 1
    else:

        # Split line by spaces to check for items on the config line
        config_line_split = config_line.split(" ")

        if config_line[0:11] == "Smart Array" or config_line[0:2] == "HP":  # New Controller

            # Initialize Dictionary for Controller
            current_controller = {
                'model': "",
                'slot': "",
                'sn': "",
                'embedded': False,
                'cages': {},
                'arrays': {},
                'enclosures': {},
                'expanders': {},
                'devices': {},
                'status': {}
            }

            if config_line[0:11] == "Smart Array":

                # Check for Model
                current_controller["model"] = config_line_split[2]
                # Check for Slot
                current_controller["slot"] = config_line_split[5]
                current_controller_slot = config_line_split[5]
                # Check for '(Embedded)'
                if len(config_line_split) > 11:
                    if config_line_split[6] == '(Embedded)':
                        current_controller["embedded"] = True
                    else:
                        config_line_embedded = False
                #Trim out the Serial Number
                sn_item = config_line_split[len(config_line_split)-1]
                current_controller["sn"] = sn_item[0:len(sn_item) - 1]

            elif config_line[0:2] == "HP":

                # Check for Model
                current_controller["model"] = config_line_split[1]
                # Check for Slot
                current_controller["slot"] = config_line_split[4]
                current_controller_slot = config_line_split[4]

                # Check for '(Embedded)'
                if config_line_split[1][-1:0] == 'i':
                     current_controller["embedded"] = True
                else:
                     config_line_embedded = False

                #Trim out the Serial Number
                sn_item = config_line_split[len(config_line_split) - 1]
                if sn_item != '()':
                    current_controller["sn"] = sn_item[0:len(sn_item) - 1]

            # Add Current Controller to hpssa_config["controllers"]
            hpssa_config["controllers"].update({current_controller_slot: current_controller})

            # Reset the Blank Line Counter
            bl_count = 0

        #Check for a Port Name
        elif config_line_split[3] == 'Port' and config_line_split[4] == 'Name:':
                #Port Names seem to pop up inconsistently in the config
                #Ignore for now
                bl_count = bl_count  # Do something to appease the compiler

        else:  # Anything but a Controller or blank line...

            #Check for a Cage - Cages have the string 'at Port'.
            # Search backwards to avoid issues with spaces in the Cage Name
            if config_line_split[len(config_line_split)-6] == 'at' and \
                config_line_split[len(config_line_split)-5] == 'Port':

                # Initialize Dictionary for Cage
                current_cage = {
                    'internal': "", # - Controller Cage is internal (bool)
                    'port': "", # - Controller Cage Port [key]+
                    'box': "", # - Controller Box Port [key]+
                    'status': "", # - Controller Cage Status
                }
                #Check for internal Cage
                if config_line_split[3] == 'External':
                    current_cage["internal"] = False
                else:
                    current_cage["internal"] = True

                #Check for Cage Status
                if config_line_split[-1][0:-1] == 'OK':

                    #Set Status
                    current_cage["status"] = config_line_split[len(config_line_split)-1]

                    #Set Port and Box
                    current_cage["port"] = config_line_split[len(config_line_split)-4]
                    current_cage["box"] = config_line_split[len(config_line_split)-2]

                else: #Cage Error Status

                    #Set Status
                    current_cage["status"] = config_line_split[len(config_line_split)-1]

                    #Set Port and Box - # ToDo - Spaces in Error status may change offsets
                    current_cage["port"] = config_line_split[len(config_line_split)-2]
                    current_cage["box"] = config_line_split[len(config_line_split)-4]

                # Add Current Cage to hpssa_config["controllers"][current_controller["slot"]]["cages"]
                hpssa_config["controllers"][current_controller_slot]["cages"].update( \
                    {current_cage["port"]+current_cage["box"]: current_cage})

            #Check for an Array - Arrays usually start with '   Array' or '   array'
            # However, it may be possible to rename an array.
            # If an array name can have spaces, it will disrupt this logic.
            # Arrays always seeem to have 'Unused Space' at positions (len -5, len -4)

            # Search backwards to avoid issues with spaces in the Array Name
            if config_line_split[3] == 'Array' or config_line_split[3] == 'array' or \
                    config_line_split[len(config_line_split) - 5] == 'Unused' and \
                    config_line_split[len(config_line_split) - 4] == 'Space:':

                # Initialize Dictionary for Array
                current_array = {
                    'name': "",  # - Array Name [key]
                    'media': "",  # - Array Media - Ex. "Solid State SATA", "SATA", "SAS", "Solid State SAS", "NVME?"
                    'unused_space': "",  # - Free Space (not configured)
                    'unused_space_unit': '',  # - Free Space Unit (MB,GB,TB,PB)
                    'logical_drives': {},  # - (6 leading spaces)
                    'physical_drives': {}  # - (6 leading spaces)
                }

                #Get Array Name - Array Name is everything (trim spaces) before the first '('
                open_paren = config_line.find('(')
                current_array["name"] = config_line[3:open_paren][0:-1]

                #Get Array Media Type - Media Type is everything from the '(' to the first ','
                first_comma = config_line.find(',')
                current_array["media"] = config_line[open_paren + 1:first_comma]

                #Get Unused Space and unit
                current_array["unused_space"] = config_line_split[len(config_line_split) - 3]
                current_array["unused_space_unit"] = config_line_split[len(config_line_split) - 1][0:2]

                # Add Current Array to hpssa_config["controllers"][current_controller["slot"]]["arrays"]
                hpssa_config["controllers"][current_controller["slot"]]["arrays"].update( \
                    {current_array["name"]: current_array})

            #Unassigned disks are also structured like an array, use the same data structure (Special Case).
            if config_line_split[3] == 'Unassigned':

                # Initialize Dictionary for (Unassigned) Array
                current_array = {
                    'name': "Unassigned",  # - Array Name [key]
                    'media': "Unassigned",  # - Unassigned
                    'unused_space': "0",  # - Free Space (not configured)
                    'unused_space_unit': 'MB',  # - Free Space Unit (MB,GB,TB,PB)
                    'logical_drives': {},  # - (6 leading spaces)
                    'physical_drives': {}  # - (6 leading spaces)
                }

                # Add Current Array to hpssa_config["controllers"][current_controller["slot"]]["arrays"]
                hpssa_config["controllers"][current_controller["slot"]]["arrays"].update( \
                    {current_array["name"]: current_array})


            if len(config_line_split) > 6:
                # Get Logical Drives
                if config_line_split[6] == 'logicaldrive':

                    # Initialize Dictionary for Logical Drive
                    current_ld =  {  # - (6 leading spaces)
                        'number': "",  # - Logical Drive Number [key]
                        'capacity_num': "",  # - Logical Drive Capacity (just the number (decimal))
                        'capacity_unit': "",  # - Logical Drive Unit of Capacity (KB, MB, GB, TB, PB)
                        'raid_level': "",  # - RAID Level (0 = Stripe, 1 = Mirror, 5 = Parity Stripe, 6 = Double Parity, 1+0 = Stripe of Mirrors)
                        'status': "",  # - Logical Drive Status
                    }

                    # Get Logical Drive Number
                    current_ld["number"] = config_line_split[7]

                    # Get Logical Drive Capacity and Unit
                    current_ld["capacity_num"] = config_line_split[8][1:]
                    current_ld["capacity_unit"] = config_line_split[9][0:2]

                    # Get Logical Drive RAID Level
                    current_ld["raid_level"] = config_line_split[11][0:-1]

                    # Get Logical Drive Status
                    current_ld["status"] = config_line_split[12][0:-1]

                    # Add Current Logical Drive to hpssa_config["controllers"][current_controller["slot"]]["arrays"][current_array_name]["logical_drives"]
                    hpssa_config["controllers"][current_controller["slot"]]["arrays"][current_array["name"]] \
                            ["logical_drives"].update({current_ld["number"]: current_ld})

                #Get Physical Drives
                if config_line_split[6] == 'physicaldrive':

                    # Initialize Dictionary for Physical Drive
                    current_pd = { # - (6 leading spaces)
                        'address': "",  # - Drive Port:Box:Bay [key]
                        'port': "",  # - Drive Port
                        'box': "",  # - Drive Box
                        'bay': "",  # - Drive Bay
                        'type': "",  # - Drive Type
                        'capacity_num': "",  # - Physical Drive Capacity (just the number (decimal))
                        'capacity_unit': "",  # - Physical Drive Unit of Capacity (KB, MB, GB, TB, PB)
                        'status': "",  # - Physical Drive Status
                        'spare': ""  # - Physical Drive Spare Status (Is drive assigned as a spare?)
                    }

                    # Get Physical Drive Address (Port:Box:Bay)
                    current_pd["address"] = config_line_split[7]
                    address_split = config_line_split[7].split(":")
                    current_pd["port"] = address_split[0]
                    current_pd["box"] = address_split[1]
                    current_pd["bay"] = address_split[2]

                    # Get Physical Drive Type (Differences in SSA versions)
                    open_paren = config_line.find('(')
                    close_paren = config_line.find(')')
                    drive_split = config_line[open_paren + 1:close_paren].split(",")
                    current_pd["type"] = drive_split[1][1:]

                    # Get Physical Drive Capacity and Unit
                    capacity_split = drive_split[2].split(" ")
                    current_pd["capacity_num"] = capacity_split[1]
                    current_pd["capacity_unit"] = capacity_split[2]

                    # Get Physical Drive Status
                    current_pd["status"] = drive_split[3][1:]

                    # Get Physical Drive Spare Status
                    if len(config_line_split) > 17:
                        if config_line_split[17][0:-1] == 'spare':
                            current_pd["spare"] = True
                        else:
                            current_pd["spare"] = False
                    else:
                        current_pd["spare"] = False

                    # Add Current Physical Drive to hpssa_config["controllers"][current_controller["slot"]]["arrays"][current_array_name]["physical_drives"]
                    hpssa_config["controllers"][current_controller["slot"]]["arrays"][current_array["name"]]\
                        ["physical_drives"].update({current_pd["address"]: current_pd})

            #Get Devices - Enclosure
            if config_line_split[3] == 'Enclosure':

                # Initialize Dictionary for Enclosure
                current_enclosure = { # - (3 leading spaces)
                    'name': "",  # - Enclosure Name - Ex. "SEP" - Not sure what it is, capture anyway
                    'vendor_id': "",  # - Enclosure Vendor ID
                    'model': "",  # - Enclosure Model
                    'device_num': "", # - Enclosure Device Number? - Not sure what it is, capture anyway
                    'port': "",  # - Enclosure Port [key]+
                    'box': "",  # - Enclosure Box [key]+
                    'wwid': ""  # - Enclosure WWID - Serial?
                }

                # Get Enclosure Name - Enclosure Name is everything (trim spaces) before the first '('
                open_paren = config_line.find('(')
                current_enclosure["name"] = config_line[3:open_paren]

                # Get Enclosure Vendor ID and Model - Contained between the first '(' and ')'
                close_paren = config_line.find(')')
                vendor_model_split = config_line[open_paren + 1:close_paren].split(",")
                current_enclosure["vendor_id"] = vendor_model_split[0][10:]
                current_enclosure["model"] = vendor_model_split[1][7:]

                # Get Enclosure Device Number - Contained after the first ')'
                current_enclosure["device_num"] = config_line[close_paren + 2:close_paren + 5]

                # Get Enclosure WWID, Port and Box - Contained between the second '(' and ')'
                open_paren = config_line.rfind('(')
                close_paren = config_line.rfind(')')
                wwid_port_box_split = config_line[open_paren + 1:close_paren].split(",")
                current_enclosure["port"] = wwid_port_box_split[1].split(":")[1][1:]
                current_enclosure["box"] = wwid_port_box_split[2].split(":")[1][1:]
                current_enclosure["wwid"] = wwid_port_box_split[0].split(":")[1][1:]

                # Add Current Enclosure to hpssa_config["controllers"][current_controller["slot"]]["enclosures"]
                hpssa_config["controllers"][current_controller["slot"]]["enclosures"]\
                    .update({current_enclosure["port"] + ':' + current_enclosure["box"]: current_enclosure})

            # Get Devices - Expander
            if config_line_split[3] == 'Expander':

                # Initialize Dictionary for Expander
                current_expander = { # - (3 leading spaces)
                    'device_num': "",  # - Expander Device Number? - Not sure what it is, capture anyway
                    'port': "",  # - Enclosure Port [key]+
                    'box': "",  # - Enclosure Box [key]+
                    'wwid': ""  # - Enclosure WWID - Serial?
                }

                # Get Expander Device Number - Expander Device Number is between 'Expander; and the first '('
                current_expander["device_num"] = config_line[12:15]

                # Get Enclosure WWID, Port and Box - Contained between the '(' and ')'
                open_paren = config_line.find('(')
                close_paren = config_line.find(')')
                wwid_port_box_split = config_line[open_paren + 1:close_paren].split(",")
                current_expander["port"] = wwid_port_box_split[1].split(":")[1][1:]
                current_expander["box"] = wwid_port_box_split[2].split(":")[1][1:]
                current_expander["wwid"] = wwid_port_box_split[0].split(":")[1][1:]

                # Add Current Expander to hpssa_config["controllers"][current_controller["slot"]]["expanders"]
                hpssa_config["controllers"][current_controller["slot"]]["expanders"] \
                    .update({current_expander["port"] + ":" + current_expander["box"]: current_expander})

            # Get Devices - SEP (Backplane?)
            if config_line_split[3] == 'SEP':

                # Initialize Dictionary for SEP (Backplane?)
                current_device = { # -  (3 leading spaces)
                    'name': "",  # - Device Name? - Ex. "SEP" - Not sure what it is, capture anyway
                    'vendor_id': "",  # - Device Vendor ID
                    'model': "",  # - Device Model
                    'device_num': "",  # - Device Number? - Not sure what it is, capture anyway
                    'wwid': ""  # - Device WWID - Serial? [key]
                }

                # Get Device Name - Enclosure Name is everything (trim spaces) before the first '('
                open_paren = config_line.find('(')
                current_device["name"] = config_line[3:open_paren]

                # Get Device Vendor ID and Model - Contained between the first '(' and ')'
                close_paren = config_line.find(')')
                vendor_model_split = config_line[open_paren + 1:close_paren].split(",")
                current_device["vendor_id"] = vendor_model_split[0][10:]
                current_device["model"] = vendor_model_split[1][7:]

                # Get Device Device Number - Contained after the first ')'
                current_device["device_num"] = config_line[close_paren + 2:close_paren + 5]

                # Get Device WWID - Contained between the second '(' and ')'
                open_paren = config_line.rfind('(')
                close_paren = config_line.rfind(')')
                wwid_split = config_line[open_paren + 1:close_paren].split(":")
                current_device["wwid"] = wwid_split[1][1:]

                # Add Current Device to hpssa_config["controllers"][current_controller["slot"]]["devices"]
                hpssa_config["controllers"][current_controller["slot"]]["devices"] \
                    .update({current_device["wwid"]: current_device})

#=========================================#
# Capture HPE SSA Status - SSAStatusAll[] #
#=========================================#

# Capture Output of HPSSA Status and store it - Commented out while we use test files
try:
    SSAStatus = []
    with subprocess.Popen([SSACmd, "ctrl", "all", "show", "status"], stdout=subprocess.PIPE,
        bufsize=1, universal_newlines=True) as SSACmdOutput:
            for line in SSACmdOutput.stdout:
                SSAStatus.append(line)
except subprocess.CalledProcessError as e:
    sys.stdout.write(f'Command {e.cmd} failed with error {e.returncode}')
    sys.exit(3)

#=======================================#
# Parse HPE SSA Status - SSAStatusAll[] #
#=======================================#

#Blank Line Counter
bl_count = 0
for status_line in SSAStatus:

    #Remove NewLine Characters
    status_line = status_line.replace("\n", "")

    #sys.stdout.write(status_line)
    if status_line == "":
        bl_count = bl_count + 1
    else:
        if status_line[0:11] == "Smart Array" or status_line[0:2] == "HP":
            
            if status_line[0:11] == "Smart Array":

                status_line_split = status_line.split(" ")
                #Check for Model
                status_model = status_line_split[2]
                #Check for Slot
                status_slot = status_line_split[5]
                #Check for '(Embedded)'
                if len(status_line_split) > 6:
                    if status_line_split[6][0:-1] == '(Embedded)':
                        status_ctrl_embedded = "e"
                    else:
                        status_ctrl_embedded = ""

            elif status_line[0:2] == "HP":

                status_line_split = status_line.split(" ")
                #Check for Model
                status_model = status_line_split[1]
                #Check for Slot
                status_slot = status_line_split[4]

                # Check for '(Embedded)'
                if status_line_split[1][-1:0] == 'i':
                    status_ctrl_embedded = "e"
                else:
                    status_ctrl_embedded = ""

            #Initialize Dictionary for Controller Status Dictionary
            hpssa_config["controllers"][status_slot]["status"] = {
                "ctrl": "",
                "cache": "",
                "batt": ""
                }

            #Reset the Blank Line Counter
            bl_count = 0

        else:
            status_line_split = status_line.split(":")

            #Detect and set Controller Status Item
            if status_line_split[0].strip(" ") == 'Controller Status':
                    hpssa_config["controllers"][status_slot]["status"]["ctrl"] = status_line_split[1].strip(" ")

            elif status_line_split[0].strip(" ") == 'Cache Status':
                    hpssa_config["controllers"][status_slot]["status"]["cache"] = status_line_split[1].strip(" ")

            elif status_line_split[0].strip(" ") == 'Battery/Capacitor Status':
                    hpssa_config["controllers"][status_slot]["status"]["batt"] = status_line_split[1].strip(" ")

#===========================================# 
# Run Checks against HPE SSA Data Structure #
#===========================================#

#Initialize Return Code to 0 - Pass
return_code = 0

#Walk Through the config's controllers dictionary...
for ctrl in hpssa_config["controllers"]:

    #Check if the controller is Embedded
    if hpssa_config["controllers"][ctrl]["embedded"]:
        embedded_line = "(Embedded) "
    else:
        embedded_line = ""

    # Check Each Controller's overall status (Fail if not 'OK')
    if hpssa_config["controllers"][ctrl]["status"]["ctrl"] != 'OK':  #Controller Critical State

        return_code = 3
        state_line = "Critical"
    else:
        state_line = "Normal"

    ctrl_line = embedded_line + "Controller " + hpssa_config["controllers"][ctrl]["model"] + " in slot " + \
                hpssa_config["controllers"][ctrl]["slot"] + " (SN:" + \
                hpssa_config["controllers"][ctrl]["sn"] + ") is in a " + state_line + " State (" + \
                hpssa_config["controllers"][ctrl]["status"]["ctrl"] + ")"
    if return_code > 0:
        print(ctrl_line)

    #Check Cache Status (Warn if not 'OK' or 'Not Configured' or Empty)
    if hpssa_config["controllers"][ctrl]["status"]["cache"] != 'OK' and\
            hpssa_config["controllers"][ctrl]["status"]["cache"] != 'Not Configured' and\
            hpssa_config["controllers"][ctrl]["status"]["cache"] != '':  #Cache Degraded State

        state_line = "Degraded"
        if return_code < 2:
            return_code = 2
    else:
        state_line = "Normal"

    ctrl_line = embedded_line + "Controller " + hpssa_config["controllers"][ctrl]["model"] + " in slot " + \
                hpssa_config["controllers"][ctrl]["slot"] + " (SN:" + \
                hpssa_config["controllers"][ctrl]["sn"] + ") Cache is in a " + state_line + " State (" + \
                hpssa_config["controllers"][ctrl]["status"]["cache"] + ")" 
    if return_code > 0:
        print(ctrl_line)

    #Check Battery/Capacitor Status (Warn if not 'OK' or Empty)
    if hpssa_config["controllers"][ctrl]["status"]["batt"] != 'OK' and \
                hpssa_config["controllers"][ctrl]["status"]["batt"] != ''         :  #Cache Battery Degraded State

        state_line = "Degraded"
        if return_code < 2:
            return_code = 2
    else:
        state_line = "Normal"

    ctrl_line = embedded_line + "Controller "+ hpssa_config["controllers"][ctrl]["model"] + " in slot " + \
                hpssa_config["controllers"][ctrl]["slot"] + " (SN:" + \
                hpssa_config["controllers"][ctrl]["sn"] + ") Cache Battery/Capacitor is in a " + state_line + " State (" + \
                hpssa_config["controllers"][ctrl]["status"]["batt"] + ")"
    if return_code > 0:
        print(ctrl_line)

    #Check Cage Status (Fail if not 'OK')
    for cage in hpssa_config["controllers"][ctrl]["cages"]:

        if hpssa_config["controllers"][ctrl]["cages"][cage]["status"] != 'OK':  # Cage is in a Critical State

            return_code = 3
            cage_code = 3
            state_line = "Critical"
        else:
            state_line = "Normal"
            cage_code = 0

        ctrl_line = embedded_line + "Controller " + hpssa_config["controllers"][ctrl]["model"] + " in slot " + \
                    hpssa_config["controllers"][ctrl]["slot"] + " (SN:" + \
                    hpssa_config["controllers"][ctrl]["sn"] + ") - Cage at Port:" + \
                    hpssa_config["controllers"][ctrl]["cages"][cage]["port"] + \
                    ", Box:" + hpssa_config["controllers"][ctrl]["cages"][cage]["box"] + \
                    " is in a " + state_line + " State (" + \
                    hpssa_config["controllers"][ctrl]["cages"][cage]["status"] + ")"

        if cage_code > 0:
            print(ctrl_line)

    #Walk Arrays for Logical and Physical Drives
    for array in hpssa_config["controllers"][ctrl]["arrays"]:

        #Check Logical Drive Status (Fail if not 'OK', Warn if Rebuilding)
        for ld in hpssa_config["controllers"][ctrl]["arrays"][array]["logical_drives"]:

            # Logical Drive is in a Normal State
            if hpssa_config["controllers"][ctrl]["arrays"][array]["logical_drives"][ld]["status"] == 'OK':

                 state_line = "Normal"
                 drive_code = 0

            # Logical Drive is in a Recovering State
            elif hpssa_config["controllers"][ctrl]["arrays"][array]["logical_drives"][ld]["status"] == 'Recovering':

                state_line = "Recovering"
                if return_code < 1:
                    return_code = 1
                    drive_code = 1

            # Logical Drive is in a Critical State
            else:

                return_code = 3
                drive_code = 3
                state_line = "Critical"

            ctrl_line = embedded_line + "Controller " + hpssa_config["controllers"][ctrl]["model"] + " in slot " + \
                        hpssa_config["controllers"][ctrl]["slot"] + " (SN:" + \
                        hpssa_config["controllers"][ctrl]["sn"] + ") - Logical Drive :" + \
                        hpssa_config["controllers"][ctrl]["arrays"][array]["logical_drives"][ld]["number"] + \
                        " is in a " + state_line + " State (" + \
                        hpssa_config["controllers"][ctrl]["arrays"][array]["logical_drives"][ld]["status"] + ")"
            if drive_code > 0:
                print(ctrl_line)

        #Check Physical Drive Status (Fail if not 'OK' - Info if not 'OK' and part of 'Unassisgned')
        for pd in hpssa_config["controllers"][ctrl]["arrays"][array]["physical_drives"]:

            # Physical Drive is in a Normal State
            if hpssa_config["controllers"][ctrl]["arrays"][array]["physical_drives"][pd]["status"] == 'OK':

                state_line = "Normal"
                drive_code = 0

            # Physical Drive is in a Rebuilding State
            elif hpssa_config["controllers"][ctrl]["arrays"][array]["physical_drives"][pd]["status"] == 'Rebuilding':

                state_line = "Recovering"
                if return_code < 1:
                    return_code = 1
                    drive_code = 1

            # Physical Drive is in a Critical State
            else:

                return_code = 3
                drive_code = 3
                state_line = "Critical"

            ctrl_line = embedded_line + "Controller " + hpssa_config["controllers"][ctrl]["model"] + " in slot " + \
                        hpssa_config["controllers"][ctrl]["slot"] + " (SN:" + \
                        hpssa_config["controllers"][ctrl]["sn"] + ") - Physical Drive at Port:" + \
                        hpssa_config["controllers"][ctrl]["arrays"][array]["physical_drives"][pd]["port"] + ", Box:" +\
                        hpssa_config["controllers"][ctrl]["arrays"][array]["physical_drives"][pd]["box"] + ", Bay:" +\
                        hpssa_config["controllers"][ctrl]["arrays"][array]["physical_drives"][pd]["bay"] + \
                        " is in a " + state_line + " State (" + \
                        hpssa_config["controllers"][ctrl]["arrays"][array]["physical_drives"][pd]["status"] + ")"
            if drive_code > 0:
                print(ctrl_line)

if return_code == 0:
    print("All Controller Checks Passed.")
sys.exit(return_code)
