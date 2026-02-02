#!/usr/bin/env python3
"""
Remote Access Detector — Windows v1 (Python)

Purpose: Detect third-party remote access tools on Windows endpoints from Tactical RMM (TRMM).
Runtime: ≤ 10s typical; single-threaded; stdlib + built-in Windows tools only.

Parameters:
  --debug                     Show per-module timings + diagnostic notes
  --kill                      Force-terminate detected processes, verify, re-scan
  --clean                     Remove services, paths, and files for detected products (includes --kill)
  --summary                   Append scan summary section
  --no-network                Skip network connection enumeration
  --no-mirror-heuristics      Disable heuristic mirror checks
  --no-mirror-api             Disable API-level mirror checks

Environment Variables:
  EXCLUDE                     Semicolon-separated exclusions supporting:
                              product=<product_key>       (e.g., product=teamviewer)
                              name=<exact_name>           (e.g., name=quickassist.exe)
                              path=<path_substring>       (e.g., path=C:\Program Files\Mesh Agent\)
                              user=<username>             (e.g., user=admin)
                              ip=<ip_address>             (e.g., ip=192.168.1.1)
                              alias=<product_alias>       (e.g., alias=TV)
                              regex_name=<pattern>        (e.g., regex_name=^ultraviewer.*)
                              regex_path=<pattern>        (e.g., regex_path=.*\\temp\\.*)
                              
                              Example: EXCLUDE=name=quickassist.exe;ip=192.168.1.1;alias=MeshCentral
                              
                              TRMM Custom Field Usage:
                              Set script env var: EXCLUDE={{agent.RemoteAccess_Exclusions}}
                              Set custom field value: product=teamviewer
                              (or multiple): product=teamviewer;alias=ScreenConnect

Exit codes:
  0 = No detections
  1 = Detections found (no kill failures)
  2 = Detections found and at least one --kill failed

Examples:

  # With multiple exclusions via environment variable (Name, IP, and Regex)
  EXCLUDE=name=quickassist.exe;ip=192.168.1.1;regex_name=^ultraviewer.*

  # Exclude based on Product Alias (defined in the script's DEFINITIONS)
  EXCLUDE=alias=TV;alias=MeshCentral;alias=NinjaOne

  # Exclude based on the internal product key
  EXCLUDE=product=teamviewer;product=screenconnect

  # Full cleanup (kill processes, remove services, delete files)
  --clean

Remote Access Tools
TeamViewer: TeamViewer, Team Viewer Host, TV
AnyDesk: AnyDesk
UltraViewer: UltraViewer
Chrome Remote Desktop: Chrome Remote Desktop, CRD
RustDesk: RustDesk
Splashtop: Splashtop
RealVNC: RealVNC, VNC Server, VNC Connect
GoTo: GoTo, GoToAssist, GoToMyPC
LogMeIn: LogMeIn
ScreenConnect: ScreenConnect, ConnectWise Control
BeyondTrust: BeyondTrust, Bomgar
DameWare: DameWare
RemotePC: RemotePC
Zoho Assist: Zoho Assist
Parsec: Parsec
MeshCentral: MeshCentral, MeshAgent
JWrapper Remote Access: JWrapper Remote Access, Remote Access

RMM Tools (New in v1.5)
NinjaOne: NinjaOne, NinjaRMM
Datto RMM: Datto RMM, Autotask Endpoint Management
Kaseya: Kaseya VSA
Syncro: Syncro
Atera: Atera
N-able: N-able, N-central, TakeControl
Tactical RMM: Tactical RMM

v1.0 silversword411 11/9/2025 initial release
v1.1 silversword411 11/9/2025 add --clean
v1.2 silversword411 11/9/2025 fix --clean so it finds process. Searches services for it's path, finds service and removes from there
v1.3 silversword411 11/9/2025 tweaking to support TRMM agent custom_fields for exclusions use.
v1.4 silversword411 12/28/2025 adding product as exclude option
v1.5 silversword411 12/30/2025 added common RMMs to definitions; added alias exclusion examples
v1.6 silversword411 1/19/2026 added JWrapper Remote Access / SimpleHelp detection; added service enumeration (detects installed services); added server URL extraction from config files; added Tactical RMM to base exclusions
v1.7 silversword411 1/19/2026 fixed product and alias exclusions to properly exclude all detections for that product
v1.8 silversword411 1/22/2026 expanded GoToAssist detection for customer variants; removed Citrix Workspace false positive

TODO
Test kill and clean on TeamViewer, AnyDesk, Chrome Remote Desktop, RustDesk, Splashtop, RealVNC, GoTo, LogMeIn, BeyondTrust, DameWare, RemotePC, Zoho Assist, and Parsec

"""

import sys
import os
import platform
import subprocess
import re
import time
import socket
import argparse
import json
from datetime import datetime, timedelta
from collections import defaultdict, OrderedDict
import xml.etree.ElementTree as ET

# ============================================================================
# Built-in Definitions
# ============================================================================

DEFINITIONS = {
    "teamviewer": {
        "aliases": ["TeamViewer", "Team Viewer Host", "TV"],
        "processes": [
            {"name": "TeamViewer.exe", "path_substr": ["\\TeamViewer\\"], "publisher": "TeamViewer"},
            {"name": "TeamViewer_Service.exe", "path_substr": ["\\TeamViewer\\"]},
            {"name": "tv_w32.exe", "path_substr": ["\\TeamViewer\\"]},
            {"name": "tv_x64.exe", "path_substr": ["\\TeamViewer\\"]}
        ],
        "services": [
            {"name": "TeamViewer", "path_substr": ["\\TeamViewer\\"]}
        ],
        "paths": ["C:\\Program Files\\TeamViewer\\", "C:\\Program Files (x86)\\TeamViewer\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "anydesk": {
        "aliases": ["AnyDesk"],
        "processes": [
            {"name": "AnyDesk.exe", "path_substr": ["\\AnyDesk\\", "\\anydesk"], "publisher": "philandro Software GmbH"}
        ],
        "services": [
            {"name": "AnyDesk", "path_substr": ["\\AnyDesk\\"]}
        ],
        "paths": ["C:\\Program Files\\AnyDesk\\", "C:\\Program Files (x86)\\AnyDesk\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "ultraviewer": {
        "aliases": ["UltraViewer"],
        "processes": [
            {"name": "UltraViewer_Desktop.exe", "path_substr": ["\\UltraViewer\\"], "publisher": "DucFabulous"},
            {"name": "UltraViewer_Service.exe", "path_substr": ["\\UltraViewer\\"]}
        ],
        "services": [
            {"name": "UltraViewService", "path_substr": ["\\UltraViewer\\"]}
        ],
        "paths": ["C:\\Program Files\\UltraViewer\\", "C:\\Program Files (x86)\\UltraViewer\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "chrome_remote_desktop": {
        "aliases": ["Chrome Remote Desktop", "CRD"],
        "processes": [
            {"name": "remoting_host.exe", "path_substr": ["\\Chrome Remote Desktop\\"], "publisher": "Google"},
            {"name": "chrome_remote_desktop_host.exe", "path_substr": ["\\Chrome Remote Desktop\\"]}
        ],
        "services": [
            {"name": "chromoting", "path_substr": ["\\Chrome Remote Desktop\\"]}
        ],
        "paths": ["C:\\Program Files\\Google\\Chrome Remote Desktop\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "rustdesk": {
        "aliases": ["RustDesk"],
        "processes": [
            {"name": "rustdesk.exe", "path_substr": ["\\RustDesk\\"], "publisher": "RustDesk"}
        ],
        "services": [
            {"name": "rustdesk", "path_substr": ["\\RustDesk\\"]}
        ],
        "paths": ["C:\\Program Files\\RustDesk\\", "C:\\Program Files (x86)\\RustDesk\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "splashtop": {
        "aliases": ["Splashtop"],
        "processes": [
            {"name": "Splashtop-streamer.exe", "path_substr": ["\\Splashtop\\"], "publisher": "Splashtop Inc."},
            {"name": "SRService.exe", "path_substr": ["\\Splashtop\\"]},
            {"name": "SRFeature.exe", "path_substr": ["\\Splashtop\\"]}
        ],
        "services": [
            {"name": "SplashtopRemoteService", "path_substr": ["\\Splashtop\\"]}
        ],
        "paths": ["C:\\Program Files\\Splashtop\\", "C:\\Program Files (x86)\\Splashtop\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "realvnc": {
        "aliases": ["RealVNC", "VNC Server", "VNC Connect"],
        "processes": [
            {"name": "vncserver.exe", "path_substr": ["\\RealVNC\\"], "publisher": "RealVNC"},
            {"name": "vncviewer.exe", "path_substr": ["\\RealVNC\\"]},
            {"name": "vnclicense.exe", "path_substr": ["\\RealVNC\\"]}
        ],
        "services": [
            {"name": "vncserver", "path_substr": ["\\RealVNC\\"]}
        ],
        "paths": ["C:\\Program Files\\RealVNC\\", "C:\\Program Files (x86)\\RealVNC\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "goto": {
        "aliases": ["GoTo", "GoToAssist", "GoToMyPC"],
        "processes": [
            {"name": "g2ax_comm_expert.exe", "path_substr": ["\\GoTo\\"], "publisher": "LogMeIn"},
            {"name": "g2ax_service.exe", "path_substr": ["\\GoTo\\"]},
            {"name": "g2ax_comm_customer.exe", "path_substr": ["\\GoTo\\", "\\GoToAssist Remote Support Customer\\"]},
            {"name": "g2ax_system_customer.exe", "path_substr": ["\\GoTo\\", "\\GoToAssist Remote Support Customer\\"]},
            {"name": "g2mui.exe", "path_substr": ["\\GoTo\\"]},
            {"name": "g2mcomm.exe", "path_substr": ["\\GoTo\\"]},
            {"name": "g2mstart.exe", "path_substr": ["\\GoTo\\"]}
        ],
        "services": [
            {"name": "GoToAssist", "path_substr": ["\\GoTo\\"], "check_running_only": True},
            {"name": "GoToAssist Remote Support Customer", "path_substr": ["\\GoTo\\", "\\GoToAssist Remote Support Customer\\"], "check_running_only": True}
        ],
        "paths": ["C:\\Program Files\\GoTo\\", "C:\\Program Files (x86)\\GoTo\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "logmein": {
        "aliases": ["LogMeIn"],
        "processes": [
            {"name": "LogMeIn.exe", "path_substr": ["\\LogMeIn\\"], "publisher": "LogMeIn"},
            {"name": "LMIGuardianSvc.exe", "path_substr": ["\\LogMeIn\\"]},
            {"name": "ramaint.exe", "path_substr": ["\\LogMeIn\\"]}
        ],
        "services": [
            {"name": "LogMeIn", "path_substr": ["\\LogMeIn\\"]}
        ],
        "paths": ["C:\\Program Files\\LogMeIn\\", "C:\\Program Files (x86)\\LogMeIn\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "screenconnect": {
        "aliases": ["ScreenConnect", "ConnectWise Control"],
        "processes": [
            {"name": "ScreenConnect.ClientService.exe", "path_substr": ["\\ScreenConnect"], "publisher": "ConnectWise"},
            {"name": "ScreenConnect.WindowsClient.exe", "path_substr": ["\\ScreenConnect", "screenconnect"]},
            {"name": "ConnectWiseControl.Client.exe", "path_substr": ["\\ConnectWise"]},
            {"name": "ConnectWiseControl.ClientService.exe", "path_substr": ["\\ConnectWise"]}
        ],
        "services": [
            {"name": "ScreenConnect", "path_substr": ["\\ScreenConnect", "\\ConnectWise"]}
        ],
        "paths": ["C:\\Program Files\\ScreenConnect\\", "C:\\Program Files (x86)\\ScreenConnect\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "beyondtrust": {
        "aliases": ["BeyondTrust", "Bomgar"],
        "processes": [
            {"name": "bomgar-scc.exe", "path_substr": ["\\Bomgar\\", "\\BeyondTrust\\"], "publisher": "BeyondTrust"},
            {"name": "bomgar-rep.exe", "path_substr": ["\\Bomgar\\", "\\BeyondTrust\\"]},
            {"name": "bomgar-rdp.exe", "path_substr": ["\\Bomgar\\", "\\BeyondTrust\\"]}
        ],
        "services": [
            {"name": "Bomgar", "path_substr": ["\\Bomgar\\", "\\BeyondTrust\\"]}
        ],
        "paths": ["C:\\Program Files\\Bomgar\\", "C:\\Program Files (x86)\\Bomgar\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "dameware": {
        "aliases": ["DameWare"],
        "processes": [
            {"name": "DWRCS.exe", "path_substr": ["\\DameWare\\"], "publisher": "SolarWinds"},
            {"name": "DameWare.exe", "path_substr": ["\\DameWare\\"]},
            {"name": "DWRCC.exe", "path_substr": ["\\DameWare\\"]}
        ],
        "services": [
            {"name": "DameWare", "path_substr": ["\\DameWare\\"]}
        ],
        "paths": ["C:\\Program Files\\DameWare\\", "C:\\Program Files (x86)\\DameWare\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "remotepc": {
        "aliases": ["RemotePC"],
        "processes": [
            {"name": "RemotePCDesktop.exe", "path_substr": ["\\RemotePC\\"], "publisher": "iDrive Inc."},
            {"name": "RemotePCService.exe", "path_substr": ["\\RemotePC\\"]}
        ],
        "services": [
            {"name": "RemotePC", "path_substr": ["\\RemotePC\\"]}
        ],
        "paths": ["C:\\Program Files\\RemotePC\\", "C:\\Program Files (x86)\\RemotePC\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "zoho_assist": {
        "aliases": ["Zoho Assist"],
        "processes": [
            {"name": "ZohoURS.exe", "path_substr": ["\\Zoho\\"], "publisher": "Zoho Corporation"},
            {"name": "ZohoAssist.exe", "path_substr": ["\\Zoho\\"]}
        ],
        "services": [
            {"name": "ZohoAssist", "path_substr": ["\\Zoho\\"]}
        ],
        "paths": ["C:\\Program Files\\Zoho\\", "C:\\Program Files (x86)\\Zoho\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "parsec": {
        "aliases": ["Parsec"],
        "processes": [
            {"name": "parsecd.exe", "path_substr": ["\\Parsec\\"], "publisher": "Parsec Cloud"},
            {"name": "parsec.exe", "path_substr": ["\\Parsec\\"]}
        ],
        "services": [
            {"name": "parsec", "path_substr": ["\\Parsec\\"]}
        ],
        "paths": ["C:\\Program Files\\Parsec\\", "C:\\Program Files (x86)\\Parsec\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "meshcentral": {
        "aliases": ["MeshCentral", "MeshAgent"],
        "processes": [
            {"name": "meshagent.exe", "path_substr": ["\\MeshAgent\\", "\\Mesh Agent\\"], "publisher": "MeshCentral"}
        ],
        "services": [
            {"name": "MeshAgent", "path_substr": ["\\MeshAgent\\", "\\Mesh Agent\\"]}
        ],
        "paths": ["C:\\Program Files\\MeshAgent\\", "C:\\Program Files\\Mesh Agent\\", "C:\\Program Files (x86)\\MeshAgent\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "jwrapper_remote_access": {
        "aliases": ["JWrapper Remote Access", "Remote Access", "SimpleHelp"],
        "processes": [
            {"name": "Remote AccessWinLauncher.exe", "path_substr": ["\\JWrapper-Remote Access\\"]},
            {"name": "SimpleService.exe", "path_substr": ["\\JWrapper-Remote Access\\"]},
            {"name": "Remote Access Service.exe", "path_substr": ["\\JWrapper-Remote Access\\"]},
            {"name": "StopSimpleGatewayService.exe", "path_substr": ["\\JWrapper-Remote Access\\"]},
            {"name": "Remote Access Monitoring.exe", "path_substr": ["\\JWrapper-Remote Access\\"]},
            {"name": "Remote Access.exe", "path_substr": ["\\JWrapper-Remote Access\\"]},
            {"name": "Remote AccessECompatibility.exe", "path_substr": ["\\JWrapper-Remote Access\\"]},
            {"name": "Remote AccessLauncher.exe", "path_substr": ["\\JWrapper-Remote Access\\"]}
        ],
        "services": [
            {"name": "Remote Access Service", "path_substr": ["\\JWrapper-Remote Access\\"]}
        ],
        "paths": [
            "C:\\ProgramData\\JWrapper-Remote Access\\",
            "C:\\ProgramData\\JWrapper-Remote Access\\JWAppsSharedConfig\\serviceconfig.xml"
        ],
        "registry": [],
        "ports": [],
        "signatures": [
            {"file": "C:\\ProgramData\\JWrapper-Remote Access\\JWAppsSharedConfig\\serviceconfig.xml", "note": "Contains server URL configuration"}
        ]
    },
    "ninjaone": {
        "aliases": ["NinjaOne", "NinjaRMM"],
        "processes": [
            {"name": "Ninja.Rm.Agent.exe", "path_substr": ["\\NinjaRMMAgent\\"], "publisher": "NinjaOne"},
            {"name": "Ninja.Rm.Service.exe", "path_substr": ["\\NinjaRMMAgent\\"]}
        ],
        "services": [
            {"name": "NinjaRMMAgent", "path_substr": ["\\NinjaRMMAgent\\"]}
        ],
        "paths": ["C:\\Program Files\\NinjaRMMAgent\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "datto_rmm": {
        "aliases": ["Datto RMM", "Autotask Endpoint Management"],
        "processes": [
            {"name": "AEMAgent.exe", "path_substr": ["\\CentraStage\\"], "publisher": "Datto"},
            {"name": "CagService.exe", "path_substr": ["\\CentraStage\\"]}
        ],
        "services": [
            {"name": "CentraStage", "path_substr": ["\\CentraStage\\"]}
        ],
        "paths": ["C:\\Program Files\\CentraStage\\", "C:\\Program Files (x86)\\CentraStage\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "kaseya": {
        "aliases": ["Kaseya VSA"],
        "processes": [
            {"name": "AgentMon.exe", "path_substr": ["\\Kaseya\\"], "publisher": "Kaseya"},
            {"name": "KaSrvc.exe", "path_substr": ["\\Kaseya\\"]}
        ],
        "services": [
            {"name": "KaseyaAgent", "path_substr": ["\\Kaseya\\"]}
        ],
        "paths": ["C:\\Kaseya\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "syncro": {
        "aliases": ["Syncro"],
        "processes": [
            {"name": "Syncro.Service.Runner.exe", "path_substr": ["\\Syncro\\"], "publisher": "Syncro"},
            {"name": "Syncro.Service.exe", "path_substr": ["\\Syncro\\"]}
        ],
        "services": [
            {"name": "Syncro", "path_substr": ["\\Syncro\\"]}
        ],
        "paths": ["C:\\Program Files\\RepairShopr\\Syncro\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "atera": {
        "aliases": ["Atera"],
        "processes": [
            {"name": "AteraAgent.exe", "path_substr": ["\\Atera Networks\\"], "publisher": "Atera"}
        ],
        "services": [
            {"name": "AteraAgent", "path_substr": ["\\Atera Networks\\"]}
        ],
        "paths": ["C:\\Program Files\\Atera Networks\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "nable": {
        "aliases": ["N-able", "N-central", "TakeControl"],
        "processes": [
            {"name": "WindowsAgent.exe", "path_substr": ["\\N-able\\"], "publisher": "N-able"},
            {"name": "BASupSrvc.exe", "path_substr": ["\\TakeControl\\"]},
            {"name": "BASupApp_ST.exe", "path_substr": ["\\TakeControl\\"]}
        ],
        "services": [
            {"name": "N-central Agent", "path_substr": ["\\N-able\\"]},
            {"name": "BASupSrvc", "path_substr": ["\\TakeControl\\"]}
        ],
        "paths": ["C:\\Program Files\\N-able Technologies\\", "C:\\Program Files (x86)\\N-able Technologies\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "tacticalrmm": {
        "aliases": ["Tactical RMM"],
        "processes": [
            {"name": "tacticalrmm.exe", "path_substr": ["\\TacticalRMM\\"], "publisher": "Tactical RMM"}
        ],
        "services": [
            {"name": "tacticalrmm", "path_substr": ["\\TacticalRMM\\"]}
        ],
        "paths": ["C:\\Program Files\\TacticalRMM\\"],
        "registry": [],
        "ports": [],
        "signatures": []
    },
    "logon_vbs_malware": {
        "aliases": ["VBS Malware Dropper"],
        "processes": [],
        "services": [],
        "paths": ["C:\\ProgramData\\Logon\\"],
        "registry": [],
        "ports": [],
        "signatures": [
            {"path": "C:\\ProgramData\\Logon\\", "pattern": "*.vbs", "note": "Malicious VBS dropper detected"}
        ]
    }
}

# ============================================================================
# Base Exclusions
# ============================================================================

BASE_EXCLUSIONS = [
    {"name": "QuickAssist.exe"},   # Microsoft Quick Assist (default excluded)
    {"name": "tacticalrmm"},   # Tactical RMM Agent (default excluded)
    {"path": "C:\\Program Files\\Mesh Agent\\MeshAgent.exe"}   # TRMM default Meshcentral path
]

# ============================================================================

WARNINGS = []
TIMINGS = {}
DEBUG_MODE = False

# ============================================================================
# Helper Functions
# ============================================================================

def time_function(func):
    """Decorator to time function execution in debug mode."""
    def wrapper(*args, **kwargs):
        if not DEBUG_MODE:
            return func(*args, **kwargs)
        
        func_name = func.__name__
        start = time.time()
        result = func(*args, **kwargs)
        elapsed = time.time() - start
        
        if func_name not in TIMINGS:
            TIMINGS[func_name] = []
        TIMINGS[func_name].append(elapsed)
        
        return result
    return wrapper

def check_environment():
    """Check Python version and OS compatibility."""
    if sys.version_info < (3, 9):
        print("Error: Python 3.9+ required", file=sys.stderr)
        sys.exit(1)
    
    if platform.system() != "Windows":
        print("Error: Windows OS required", file=sys.stderr)
        sys.exit(1)

def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Remote Access Detector for Windows")
    parser.add_argument("--debug", action="store_true", help="Show per-module timings and diagnostics")
    parser.add_argument("--kill", action="store_true", help="Force-terminate detected processes")
    parser.add_argument("--clean", action="store_true", help="Remove services, paths, and files (includes --kill)")
    parser.add_argument("--summary", action="store_true", help="Append scan summary section")
    parser.add_argument("--no-network", action="store_true", help="Skip network connection enumeration")
    parser.add_argument("--no-mirror-heuristics", action="store_true", help="Disable heuristic mirror checks")
    parser.add_argument("--no-mirror-api", action="store_true", help="Disable API-level mirror checks")
    return parser.parse_args()

def load_definitions():
    """Load product definitions."""
    return DEFINITIONS

def load_base_exclusions():
    """Load base exclusions."""
    return BASE_EXCLUSIONS.copy()

def parse_exclusions_from_flags(args):
    """Parse exclusions from EXCLUDE environment variable into structured format."""
    exclusions = []
    
    # Get exclusions from environment variable
    env_exclude = os.environ.get("EXCLUDE", "").strip()
    if not env_exclude:
        return exclusions
    
    # Split by semicolon for multiple exclusions
    env_items = [item.strip() for item in env_exclude.split(";") if item.strip()]
    
    for excl in env_items:
        if "=" not in excl:
            WARNINGS.append(f"Warning: invalid exclusion format '{excl}', expected key=value")
            continue
        key, value = excl.split("=", 1)
        key = key.strip().lower()
        value = value.strip()
        
        if key in ["name", "path", "user", "ip", "product", "alias"]:
            exclusions.append({key: value})
        elif key in ["regex_name", "regex_path"]:
            try:
                compiled = re.compile(value, re.IGNORECASE)
                exclusions.append({key: compiled, f"{key}_raw": value})
            except re.error as e:
                WARNINGS.append(f"Warning: invalid regex in exclusion '{excl}': {e}")
        else:
            WARNINGS.append(f"Warning: unsupported exclusion key '{key}'")
    
    return exclusions

def normalize_name(s):
    """Normalize process name for comparison."""
    if not s:
        return ""
    return s.lower().strip()

def normalize_path(p):
    """Normalize path for comparison."""
    if not p:
        return ""
    return p.lower().replace("/", "\\").strip()

def format_uptime(start_time_str):
    """Convert start time to uptime in HH:MM:SS format."""
    try:
        # Parse WMI datetime format: 20241109123045.123456-300
        if "." in start_time_str:
            dt_part = start_time_str.split(".")[0]
        else:
            dt_part = start_time_str
        
        start_time = datetime.strptime(dt_part[:14], "%Y%m%d%H%M%S")
        uptime = datetime.now() - start_time
        total_seconds = int(uptime.total_seconds())
        hours = total_seconds // 3600
        minutes = (total_seconds % 3600) // 60
        seconds = total_seconds % 60
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    except:
        return "[unknown]"

@time_function
def enumerate_processes(definitions=None):
    """
    Enumerate running processes with details (no WMIC).
    """
    processes = []
    ps_cmd = r"""
$ErrorActionPreference = 'SilentlyContinue'
$procs = Get-CimInstance Win32_Process | Select-Object ProcessId, Name, ExecutablePath, ParentProcessId, CreationDate
$pidName = @{}
foreach ($p in $procs) { $pidName[[int]$p.ProcessId] = [string]$p.Name }
$procs | ForEach-Object {
    $pid  = [int]$_.ProcessId
    $ppid = [int]$_.ParentProcessId
    [pscustomobject]@{
        pid           = $pid
        name          = [string]$_.Name
        path          = if ([string]::IsNullOrWhiteSpace($_.ExecutablePath)) { "" } else { [string]$_.ExecutablePath }
        ppid          = $ppid
        parent_name   = if ($pidName.ContainsKey($ppid)) { $pidName[$ppid] } else { "" }
        creation_date = if ($null -eq $_.CreationDate) { "" } else { [string]$_.CreationDate }
    }
} | ConvertTo-Json -Compress -Depth 3
""".strip()

    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", ps_cmd],
            capture_output=True,
            text=True,
            timeout=20,
            creationflags=0x08000000
        )

        if result.returncode != 0 or not result.stdout.strip():
            WARNINGS.append("Warning: PowerShell process enumeration failed")
            return processes

        data = json.loads(result.stdout)
        if isinstance(data, dict):
            data = [data]

        for p in data:
            pid = int(p.get("pid") or 0)
            name = (p.get("name") or "").strip()
            path = p.get("path") or ""
            ppid = int(p.get("ppid") or 0)
            parent_name = (p.get("parent_name") or "").strip()
            cdate = (p.get("creation_date") or "").strip()

            proc = {
                "pid": pid,
                "name": name if name else "[unknown]",
                "path": path if path else "[unknown]",
                "user": "[unknown]",
                "ppid": ppid,
                "parent_name": parent_name if parent_name else "[unknown]",
                "uptime": format_uptime(cdate) if cdate else "[unknown]"
            }
            processes.append(proc)

        if not definitions:
            return processes

        matched_pids = []
        for proc in processes:
            product_key = match_process_to_product(proc, definitions)
            if product_key:
                matched_pids.append(proc["pid"])

        if not matched_pids:
            return processes

        pid_csv = ",".join(str(int(x)) for x in sorted(set(matched_pids)))
        ps_owner_cmd = rf"""
$ErrorActionPreference = 'SilentlyContinue'
$pids = @({pid_csv})
$rows = foreach ($pid in $pids) {{
    $owner = ""
    try {{
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$pid"
        if ($null -ne $p) {{
            try {{ $owner = (Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction Stop).User }} catch {{}}
        }}
    }} catch {{}}
    [pscustomobject]@{{ pid = [int]$pid; owner = [string]$owner }}
}}
$rows | ConvertTo-Json -Compress -Depth 3
""".strip()

        owner_map = {}
        try:
            owner_res = subprocess.run(
                ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", ps_owner_cmd],
                capture_output=True,
                text=True,
                timeout=15,
                creationflags=0x08000000
            )
            if owner_res.returncode == 0 and owner_res.stdout.strip():
                owner_data = json.loads(owner_res.stdout)
                if isinstance(owner_data, dict):
                    owner_data = [owner_data]
                for row in owner_data:
                    try:
                        opid = int(row.get("pid") or 0)
                        owner = (row.get("owner") or "").strip()
                        if owner:
                            owner_map[opid] = owner
                    except Exception:
                        continue
        except Exception:
            pass

        if owner_map:
            for proc in processes:
                if proc["pid"] in owner_map:
                    proc["user"] = owner_map[proc["pid"]]

    except subprocess.TimeoutExpired:
        WARNINGS.append("Warning: process enumeration timed out")
    except Exception as e:
        WARNINGS.append(f"Warning: process enumeration error: {e}")

    return processes

@time_function
def enumerate_services(definitions=None):
    """Enumerate installed Windows services with details."""
    services = []
    ps_cmd = r"""
$ErrorActionPreference = 'SilentlyContinue'
Get-CimInstance Win32_Service | Select-Object Name, DisplayName, PathName, State, StartMode | ForEach-Object {
    [pscustomobject]@{
        name         = [string]$_.Name
        display_name = [string]$_.DisplayName
        path         = if ([string]::IsNullOrWhiteSpace($_.PathName)) { "" } else { [string]$_.PathName }
        state        = [string]$_.State
        start_mode   = [string]$_.StartMode
    }
} | ConvertTo-Json -Compress -Depth 3
""".strip()

    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", ps_cmd],
            capture_output=True,
            text=True,
            timeout=45,
            creationflags=0x08000000
        )

        if result.returncode != 0 or not result.stdout.strip():
            WARNINGS.append("Warning: PowerShell service enumeration failed")
            return services

        data = json.loads(result.stdout)
        if isinstance(data, dict):
            data = [data]

        for s in data:
            name = (s.get("name") or "").strip()
            display_name = (s.get("display_name") or "").strip()
            path = s.get("path") or ""
            state = (s.get("state") or "").strip()
            start_mode = (s.get("start_mode") or "").strip()

            svc = {
                "name": name if name else "[unknown]",
                "display_name": display_name if display_name else "[unknown]",
                "path": path if path else "[unknown]",
                "state": state if state else "[unknown]",
                "start_mode": start_mode if start_mode else "[unknown]"
            }
            services.append(svc)

    except subprocess.TimeoutExpired:
        WARNINGS.append("Warning: service enumeration timed out")
    except Exception as e:
        WARNINGS.append(f"Warning: service enumeration error: {e}")

    return services

@time_function
def collect_netstat():
    """Collect network connections via netstat."""
    connections = []
    try:
        result = subprocess.run(["netstat", "-ano", "-p", "TCP"], 
                              capture_output=True, text=True, timeout=5,
                              creationflags=0x08000000)
        if result.returncode != 0:
            return None
        
        lines = result.stdout.split("\n")
        for line in lines:
            line = line.strip()
            if not line or line.startswith("Active") or line.startswith("Proto"):
                continue
            parts = line.split()
            if len(parts) < 5:
                continue
            proto = parts[0]
            if proto != "TCP":
                continue
            local = parts[1]
            remote = parts[2]
            state = parts[3]
            pid = parts[4]
            if state not in ["LISTENING", "ESTABLISHED"]:
                continue
            try:
                pid = int(pid)
                connections.append({
                    "proto": proto, "local": local, "remote": remote, "state": state, "pid": pid
                })
            except ValueError:
                continue
        return connections
    except Exception as e:
        WARNINGS.append(f"Warning: netstat error: {e}")
        return None

@time_function
def collect_net_ps_fallback():
    """Fallback: collect connections via PowerShell."""
    connections = []
    try:
        ps_cmd = "Get-NetTCPConnection | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess | ConvertTo-Csv -NoTypeInformation"
        result = subprocess.run(["powershell", "-Command", ps_cmd], 
                              capture_output=True, text=True, timeout=15)
        if result.returncode != 0:
            return None
        lines = result.stdout.strip().split("\n")
        if len(lines) < 2:
            return None
        for line in lines[1:]:
            parts = line.strip('"').split('","')
            if len(parts) < 6:
                continue
            try:
                local_addr = parts[0].strip('"')
                local_port = parts[1].strip('"')
                remote_addr = parts[2].strip('"')
                remote_port = parts[3].strip('"')
                state = parts[4].strip('"')
                pid = int(parts[5].strip('"'))
                local = f"{local_addr}:{local_port}"
                remote = f"{remote_addr}:{remote_port}"
                connections.append({
                    "proto": "TCP", "local": local, "remote": remote, "state": state, "pid": pid
                })
            except (ValueError, IndexError):
                continue
        return connections
    except Exception as e:
        WARNINGS.append(f"Warning: PowerShell fallback error: {e}")
        return None

@time_function
def reverse_dns(ip):
    """Perform reverse DNS lookup with timeout."""
    try:
        if ip in ["0.0.0.0", "127.0.0.1", "::1", "*"]:
            return None
        socket.setdefaulttimeout(2)
        hostname = socket.gethostbyaddr(ip)[0]
        return hostname
    except Exception:
        return None
    finally:
        socket.setdefaulttimeout(None)

@time_function
def map_connections_by_pid(no_network, detected_pids=None):
    """Map network connections to PIDs."""
    if no_network:
        return {}
    conn_map = defaultdict(lambda: {"listening_count": 0, "outgoing": []})
    connections = collect_netstat()
    if connections is None:
        connections = collect_net_ps_fallback()
    if connections is None:
        return conn_map
    
    if detected_pids is not None:
        connections = [c for c in connections if c["pid"] in detected_pids]
    
    for conn in connections:
        pid = conn["pid"]
        state = conn["state"]
        remote = conn["remote"]
        if state == "LISTENING" or state == "LISTEN":
            conn_map[pid]["listening_count"] += 1
        elif state == "ESTABLISHED":
            if ":" in remote:
                ip, port = remote.rsplit(":", 1)
                ip = ip.strip("[]")
                rdns = None
                if detected_pids is None or pid in detected_pids:
                    rdns = reverse_dns(ip)
                conn_map[pid]["outgoing"].append((ip, port, state, rdns))
    return dict(conn_map)

@time_function
def mirror_check_heuristics(enabled):
    """Check for screen mirroring using heuristics."""
    if not enabled:
        return []
    return []

@time_function
def mirror_check_api(enabled):
    """Check for screen mirroring using Windows APIs."""
    if not enabled:
        return []
    return []

def extract_server_url(config_file_path, product_key):
    """Extract server URL from config files for specific products."""
    if not os.path.exists(config_file_path):
        return None
    
    try:
        if product_key == "jwrapper_remote_access":
            # Parse serviceconfig.xml for JWrapper/SimpleHelp
            tree = ET.parse(config_file_path)
            root = tree.getroot()
            connect_to = root.find(".//ConnectTo")
            if connect_to is not None and connect_to.text:
                return connect_to.text.strip()
        elif product_key == "screenconnect":
            # For ScreenConnect, extract from service path (if needed later)
            pass
    except Exception:
        pass
    
    return None

def extract_product_urls(product_key, definitions):
    """Extract server URLs for a detected product."""
    urls = []
    product_def = definitions.get(product_key, {})
    
    # Check signature files for URLs
    for sig in product_def.get("signatures", []):
        file_path = sig.get("file")
        if file_path:
            url = extract_server_url(file_path, product_key)
            if url:
                urls.append(url)
    
    return urls

@time_function
def check_file_signatures(definitions):
    """Check for file-based signatures (e.g., malware droppers)."""
    findings = []
    
    for product_key, product_def in definitions.items():
        for sig in product_def.get("signatures", []):
            sig_path = sig.get("path")
            sig_pattern = sig.get("pattern")
            sig_note = sig.get("note", "")
            
            if sig_path and sig_pattern:
                # Check if directory exists
                if not os.path.exists(sig_path):
                    continue
                
                import glob
                pattern_path = os.path.join(sig_path, sig_pattern)
                matched_files = glob.glob(pattern_path)
                
                if matched_files:
                    findings.append({
                        "product_key": product_key,
                        "files": matched_files,
                        "note": sig_note
                    })
    
    return findings

def match_process_to_product(proc, definitions):
    """Match a process to a product definition."""
    proc_name = normalize_name(proc["name"])
    proc_path = normalize_path(proc["path"])
    for product_key, product_def in definitions.items():
        for proc_def in product_def.get("processes", []):
            def_name = normalize_name(proc_def["name"])
            if proc_name != def_name:
                continue
            path_substrs = proc_def.get("path_substr", [])
            if path_substrs and proc_path != "[unknown]":
                path_match = any(normalize_path(substr) in proc_path for substr in path_substrs)
                if not path_match:
                    continue
            return product_key
    return None

def match_service_to_product(svc, definitions):
    """Match a service to a product definition. Returns (product_key, service_def) or (None, None)."""
    svc_name = normalize_name(svc["name"])
    svc_path = normalize_path(svc["path"])
    for product_key, product_def in definitions.items():
        for svc_def in product_def.get("services", []):
            def_name = normalize_name(svc_def.get("name", ""))
            if def_name and svc_name == def_name:
                # Exact service name match
                return product_key, svc_def
            # Check path substring match
            path_substrs = svc_def.get("path_substr", [])
            if path_substrs and svc_path != "[unknown]":
                path_match = any(normalize_path(substr) in svc_path for substr in path_substrs)
                if path_match:
                    return product_key, svc_def
    return None, None

def apply_exclusions(item, exclusions):
    """Check if an item should be excluded."""
    item_name = normalize_name(item.get("name", ""))
    item_path = normalize_path(item.get("path", ""))
    item_user = (item.get("user", "") or "").lower()
    item_product = (item.get("product_key") or "").lower()

    for excl in exclusions:
        if "product" in excl:
            if item_product and item_product == excl["product"].lower().strip():
                return True

        if "alias" in excl:
            alias = excl["alias"].lower().strip()
            if item_product and alias == item_product:
                return True
            if item_product in DEFINITIONS:
                aliases = [a.lower() for a in DEFINITIONS[item_product].get("aliases", [])]
                if alias in aliases:
                    return True

        if "name" in excl:
            if item_name == normalize_name(excl["name"]):
                return True

        if "path" in excl:
            if normalize_path(excl["path"]) in item_path:
                return True

        if "user" in excl:
            if excl["user"].lower() in item_user:
                return True

        if "regex_name" in excl:
            if excl["regex_name"].search(item_name):
                return True

        if "regex_path" in excl:
            if excl["regex_path"].search(item_path):
                return True

        if "ip" in excl:
            connections = item.get("connections", {}) or {}
            outgoing = connections.get("outgoing", []) or []
            excl_ip = excl["ip"].lower().strip()
            for ip, _, _, _ in outgoing:
                if (ip or "").lower() == excl_ip:
                    return True
    return False

@time_function
def group_findings(processes, services, conns_by_pid, mirror_results, definitions, exclusions, file_sigs=None):
    """Group findings by product."""
    findings = OrderedDict()
    
    # Check if entire product is excluded by product key or alias
    def is_product_excluded(product_key):
        """Check if a product is excluded by product key or alias."""
        for excl in exclusions:
            # Check direct product exclusion
            if "product" in excl:
                if product_key.lower() == excl["product"].lower().strip():
                    return True
            
            # Check alias exclusion
            if "alias" in excl:
                alias = excl["alias"].lower().strip()
                if product_key.lower() == alias:
                    return True
                if product_key in definitions:
                    aliases = [a.lower() for a in definitions[product_key].get("aliases", [])]
                    if alias in aliases:
                        return True
        return False
    
    # Process detection
    for proc in processes:
        product_key = match_process_to_product(proc, definitions)
        if not product_key:
            continue
        
        # Skip if entire product is excluded
        if is_product_excluded(product_key):
            continue
            
        proc["product_key"] = product_key
        conns = conns_by_pid.get(proc["pid"], {"listening_count": 0, "outgoing": []})
        proc["connections"] = conns
        if apply_exclusions(proc, exclusions):
            continue
        if product_key not in findings:
            # Extract server URLs for this product
            server_urls = extract_product_urls(product_key, definitions)
            findings[product_key] = {
                "product_name": definitions[product_key]["aliases"][0],
                "processes": [],
                "services": [],
                "mirrors": [],
                "server_urls": server_urls,
                "file_signatures": []
            }
        findings[product_key]["processes"].append(proc)
    
    # Service detection
    for svc in services:
        product_key, svc_def = match_service_to_product(svc, definitions)
        if not product_key:
            continue
        
        # Skip if entire product is excluded
        if is_product_excluded(product_key):
            continue
            
        svc["product_key"] = product_key
        
        # Check if service should only be reported when running
        if svc_def and svc_def.get("check_running_only", False):
            svc_state = normalize_name(svc.get("state", ""))
            if svc_state != "running":
                continue
        
        if apply_exclusions(svc, exclusions):
            continue
        if product_key not in findings:
            # Extract server URLs for this product
            server_urls = extract_product_urls(product_key, definitions)
            findings[product_key] = {
                "product_name": definitions[product_key]["aliases"][0],
                "processes": [],
                "services": [],
                "mirrors": [],
                "server_urls": server_urls,
                "file_signatures": []
            }
        findings[product_key]["services"].append(svc)
    
    # File signature detection
    if file_sigs:
        for sig_finding in file_sigs:
            product_key = sig_finding["product_key"]
            
            # Skip if entire product is excluded
            if is_product_excluded(product_key):
                continue
                
            if product_key not in findings:
                server_urls = extract_product_urls(product_key, definitions)
                findings[product_key] = {
                    "product_name": definitions[product_key]["aliases"][0],
                    "processes": [],
                    "services": [],
                    "mirrors": [],
                    "server_urls": server_urls,
                    "file_signatures": []
                }
            findings[product_key]["file_signatures"].extend([
                {"file": f, "note": sig_finding["note"]} for f in sig_finding["files"]
            ])
    
    return findings

@time_function
def kill_detected(findings, exclusions):
    """Kill detected processes and verify."""
    killed_results = []
    for product_key, product_data in findings.items():
        for proc in product_data["processes"]:
            if apply_exclusions(proc, exclusions):
                continue
            pid, name = proc["pid"], proc["name"]
            try:
                subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True, timeout=5)
                killed = False
                for _ in range(3):
                    time.sleep(1)
                    check_cmd = f"tasklist /FI \"PID eq {pid}\" /NH"
                    result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
                    if "No tasks" in result.stdout or str(pid) not in result.stdout:
                        killed = True
                        break
                killed_results.append({"name": name, "result": "success" if killed else "failed"})
            except Exception:
                killed_results.append({"name": name, "result": "failed"})
    return killed_results

@time_function
def clean_detected(findings, definitions, exclusions):
    """Remove services, paths, and files for detected products."""
    cleaned_results = {"services": [], "paths": []}
    for product_key, product_data in findings.items():
        has_non_excluded = False
        detected_process_dirs = []
        for proc in product_data["processes"]:
            if not apply_exclusions(proc, exclusions):
                has_non_excluded = True
                proc_path = proc.get("path", "")
                if proc_path and proc_path != "[unknown]":
                    proc_dir = os.path.dirname(proc_path)
                    if proc_dir not in detected_process_dirs:
                        detected_process_dirs.append(proc_dir)
        if not has_non_excluded:
            continue

        product_def = definitions.get(product_key, {})
        product_name = product_def.get("aliases", [product_key])[0]
        discovered_services = []
        try:
            query_cmd = 'Get-WmiObject Win32_Service | Select-Object Name, PathName | ConvertTo-Csv -NoTypeInformation'
            query_result = subprocess.run(["powershell", "-Command", query_cmd], capture_output=True, text=True, timeout=15)
            if query_result.returncode == 0:
                lines = query_result.stdout.strip().split("\n")
                for line in lines[1:]:
                    parts = line.strip('"').split('","')
                    if len(parts) >= 2:
                        svc_name, svc_path = parts[0].strip('"'), normalize_path(parts[1].strip('"'))
                        for proc_dir in detected_process_dirs:
                            if normalize_path(proc_dir) in svc_path:
                                discovered_services.append(svc_name)
                                break
        except Exception:
            pass

        for svc_name in discovered_services:
            try:
                subprocess.run(["sc", "stop", svc_name], capture_output=True, timeout=10)
                time.sleep(1)
                subprocess.run(["sc", "delete", svc_name], capture_output=True, timeout=10)
                cleaned_results["services"].append({"product": product_name, "name": svc_name, "result": "removed"})
            except Exception as e:
                cleaned_results["services"].append({"product": product_name, "name": svc_name, "result": f"failed: {e}"})

        all_paths = list(set(list(product_def.get("paths", [])) + detected_process_dirs))
        for path_def in all_paths:
            if not path_def: continue
            try:
                remove_cmd = f"Remove-Item -Path '{path_def}' -Recurse -Force -ErrorAction SilentlyContinue"
                subprocess.run(["powershell", "-Command", remove_cmd], capture_output=True, timeout=30)
                cleaned_results["paths"].append({"product": product_name, "path": path_def, "result": "removed/cleaned"})
            except Exception as e:
                cleaned_results["paths"].append({"product": product_name, "path": path_def, "result": f"failed: {e}"})
    return cleaned_results

def print_output(findings, killed, args, timings, warnings, mirroring_status, cleaned=None):
    """Print formatted output."""
    if killed:
        print("Detections Found (killed)\n[Killed]")
        for k in killed: print(f"  {k['name']} — {k['result']}")
        print()
    if findings:
        if not killed: print("Detections Found\n")
        for pk, pd in findings.items():
            print(f"— {pd['product_name']} —")
            # Display server URLs if found
            server_urls = pd.get("server_urls", [])
            if server_urls:
                print(f"Server URL(s): {', '.join(server_urls)}")
            for proc in pd["processes"]:
                print(f"Indicator: process\n  Name: {proc['name']}\n  Path: {proc['path']}\n  User: {proc['user']}\n  Uptime: {proc['uptime']}")
                conns = proc.get("connections", {"listening_count": 0, "outgoing": []})
                print(f"  Listening: {conns['listening_count']}")
                if conns["outgoing"]:
                    print("  Outgoing:")
                    for ip, port, state, rdns in conns["outgoing"]:
                        rdns_str = f" [{rdns}]" if rdns else ""
                        print(f"    - {ip}:{port} ({state}){rdns_str}")
                print()
            for svc in pd.get("services", []):
                print(f"Indicator: service\n  Name: {svc['name']}\n  Display Name: {svc['display_name']}\n  Path: {svc['path']}\n  State: {svc['state']}\n  Start Mode: {svc['start_mode']}")
                print()
            for file_sig in pd.get("file_signatures", []):
                print(f"Indicator: file signature\n  File: {file_sig['file']}\n  Note: {file_sig['note']}")
                print()
    elif not killed:
        print("No remote access software detected.\n")
    if cleaned:
        print("[Cleaned]")
        for svc in cleaned["services"]: print(f"    Svc: {svc['product']}: {svc['name']} — {svc['result']}")
        for path in cleaned["paths"]: print(f"    Path: {path['product']}: {path['path']} — {path['result']}")
        print()
    if args.summary:
        print(f"Scan Summary:\n  Processes: {timings.get('process_count', 0)}\n  Runtime: {timings.get('total', 0):.2f}s\n  {mirroring_status}")
    if warnings:
        for warning in warnings: print(warning)

def main():
    start_time = time.time()
    check_environment()
    args = parse_args()
    global DEBUG_MODE
    DEBUG_MODE = args.debug

    definitions = load_definitions()
    all_exclusions = load_base_exclusions() + parse_exclusions_from_flags(args)

    processes = enumerate_processes(definitions)
    services = enumerate_services(definitions)
    file_sigs = check_file_signatures(definitions)
    TIMINGS["process_count"] = len(processes)
    TIMINGS["service_count"] = len(services)

    detected_pids = set()
    for proc in processes:
        pk = match_process_to_product(proc, definitions)
        if pk:
            proc["product_key"] = pk
            detected_pids.add(proc["pid"])

    conns_by_pid = map_connections_by_pid(args.no_network, detected_pids)
    findings = group_findings(processes, services, conns_by_pid, [], definitions, all_exclusions, file_sigs)

    killed, cleaned = [], None
    if (args.kill or args.clean) and findings:
        killed = kill_detected(findings, all_exclusions)
        if args.clean:
            cleaned = clean_detected(findings, definitions, all_exclusions)
        processes = enumerate_processes(definitions)
        services = enumerate_services(definitions)
        file_sigs = check_file_signatures(definitions)
        findings = group_findings(processes, services, conns_by_pid, [], definitions, all_exclusions, file_sigs)

    TIMINGS["total"] = time.time() - start_time
    print_output(findings, killed, args, TIMINGS, WARNINGS, "Mirror checks skipped", cleaned)
    sys.exit(2 if any(k['result'] == 'failed' for k in killed) else (1 if findings or killed else 0))

if __name__ == "__main__":
    main()