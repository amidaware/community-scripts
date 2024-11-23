#!/usr/bin/python3
# v2.2 11/23/2024 silversword411 Rewrite

import win32evtlog
from datetime import datetime


def is_system_account(username):
    """Check if the account is a system account to exclude."""
    system_accounts = [
        "DWM-",
        "UMFD-",
        "ANONYMOUS LOGON",
        "LOCAL SERVICE",
        "NETWORK SERVICE",
        "SYSTEM",
        "Font Driver Host",
    ]
    for sys_account in system_accounts:
        if sys_account in username:
            return True
    return False


def process_events():
    """Collect Logon Type 2 and 10 and system startup/shutdown events into a timeline."""
    events_list = []
    logon_sessions = {}  # Key: Logon ID, Value: Event Data

    # Define event IDs and log types
    security_logtype = "Security"
    system_logtype = "System"
    logon_event_id = 4624
    logoff_event_id = 4634
    special_logon_event_id = 4672
    startup_event_ids = [6005]  # System startup
    shutdown_event_ids = [6006, 6008]  # System shutdown and unexpected shutdown

    # Open event logs
    server = "localhost"
    security_handle = win32evtlog.OpenEventLog(server, security_logtype)
    system_handle = win32evtlog.OpenEventLog(server, system_logtype)

    # Read Security events (logon/logoff and special logon)
    flags = win32evtlog.EVENTLOG_FORWARDS_READ | win32evtlog.EVENTLOG_SEQUENTIAL_READ
    events = True
    while events:
        events = win32evtlog.ReadEventLog(security_handle, flags, 0)
        if events:
            for event in events:
                event_id = event.EventID & 0xFFFF
                time_generated = event.TimeGenerated
                strings = event.StringInserts
                if event_id == logon_event_id:
                    # Process logon event
                    if strings:
                        logon_type = strings[8]  # LogonType
                        logon_id = strings[7]  # TargetLogonId
                        username = strings[5]  # TargetUserName
                        domain = strings[6]  # TargetDomainName
                        full_username = f"{domain}\\{username}"
                        # Include Logon Types 2 and 10
                        if logon_type in ["2", "10"] and not is_system_account(
                            username
                        ):
                            event_dict = {
                                "time": time_generated,
                                "event_type": "Logon",
                                "user": full_username,
                                "logon_type": logon_type,
                                "logon_id": logon_id,
                                "is_admin": False,  # Default to False
                            }
                            logon_sessions[logon_id] = event_dict
                elif event_id == logoff_event_id:
                    # Process logoff event
                    if strings:
                        logon_type = strings[4]  # LogonType
                        logon_id = strings[3]  # SubjectLogonId
                        username = strings[1]  # SubjectUserName
                        domain = strings[2]  # SubjectDomainName
                        full_username = f"{domain}\\{username}"
                        if logon_type in ["2", "10"] and not is_system_account(
                            username
                        ):
                            # Logoff events are appended directly to the events list
                            event_dict = {
                                "time": time_generated,
                                "event_type": "Logoff",
                                "user": full_username,
                                "logon_type": logon_type,
                                "logon_id": logon_id,
                            }
                            events_list.append(event_dict)
                elif event_id == special_logon_event_id:
                    # Process special logon event
                    if strings:
                        # The index for SubjectLogonId may vary, adjust if necessary
                        logon_id = strings[3]  # SubjectLogonId
                        if logon_id in logon_sessions:
                            # Mark the session as admin
                            logon_sessions[logon_id]["is_admin"] = True
        else:
            break

    # Add the logon sessions to the events list
    for logon_event in logon_sessions.values():
        events_list.append(logon_event)

    # Read System events (startup/shutdown)
    flags = win32evtlog.EVENTLOG_FORWARDS_READ | win32evtlog.EVENTLOG_SEQUENTIAL_READ
    events = True
    while events:
        events = win32evtlog.ReadEventLog(system_handle, flags, 0)
        if events:
            for event in events:
                event_id = event.EventID & 0xFFFF
                time_generated = event.TimeGenerated
                if event_id in startup_event_ids:
                    event_dict = {
                        "time": time_generated,
                        "event_type": "System Startup",
                        "details": "The Event log service was started.",
                    }
                    events_list.append(event_dict)
                elif event_id in shutdown_event_ids:
                    if event_id == 6006:
                        reason = "The Event log service was stopped."
                    elif event_id == 6008:
                        reason = "The previous system shutdown was unexpected."
                    event_dict = {
                        "time": time_generated,
                        "event_type": "System Shutdown",
                        "details": reason,
                    }
                    events_list.append(event_dict)
        else:
            break

    # Close event logs
    win32evtlog.CloseEventLog(security_handle)
    win32evtlog.CloseEventLog(system_handle)

    # Sort events by time
    events_list.sort(key=lambda x: x["time"])

    # Define logon type descriptions
    logon_type_descriptions = {
        "2": "Interactive (Console)",
        "10": "Remote Interactive (RDP)",
    }

    # Output events in chronological order
    for event in events_list:
        time_str = event["time"].Format()
        if event["event_type"] == "Logon":
            admin_status = "Admin" if event.get("is_admin", False) else "User"
            logon_method = logon_type_descriptions.get(event["logon_type"], "Unknown")
            print(
                f"{event['event_type']} Event: {time_str}, User: {event['user']}, "
                f"Logon Method: {logon_method}, Status: {admin_status}"
            )
        elif event["event_type"] == "Logoff":
            logon_method = logon_type_descriptions.get(event["logon_type"], "Unknown")
            print(
                f"{event['event_type']} Event: {time_str}, User: {event['user']}, "
                f"Logon Method: {logon_method}"
            )
        else:
            print(f"{event['event_type']}: {time_str}, Details: {event['details']}")


def main():
    process_events()


if __name__ == "__main__":
    main()
