#!/usr/bin/env python3

# Version: 0.1.0
# Author: David Randall
# GitHUb: github.com/NiceGuyIT
# URL: NiceGuyIT.biz
# License: MIT
#
# Parse Synology Active Backup for Business log files
# This example will return the ERRORs from the last hour
import datetime
# TRMM snippet for production
{{synology_activebackuplogs_snippet.py}}
# Dev
# import synology_activebackuplogs_snippet


def main():
    # timedelta docs: https://docs.python.org/3/library/datetime.html#timedelta-objects
    # Note: "years" is not valid. Use "days=365" to represent one year.
    # Values include:
    #   weeks
    #   days
    #   hours
    #   minutes
    #   seconds
    after = datetime.timedelta(hours=1)

    # Production using TRMM snippet
    logs = SynologyActiveBackupLogs(
        # Development
        # logs = synology_activebackuplogs_snippet.SynologyActiveBackupLogs(

        # Search logs within the period specified.
        # timedelta() will be off by 1 minute because 1 minute is added to detect if the log entry is last year vs.
        # this year. This should be negligible.
        after=after,

        # Use different log location
        # log_path="custom/log/path",

        # Use different filename globbing
        # filename_glob="log.txt*",
    )

    # Load the log entries
    logs.load()

    # Search for entries that match the criteria.
    find = {
        'priority': 'ERROR',
    }
    found = logs.search(find=find)
    if not found:
        # The timestamp above is not
        ts = (datetime.datetime.now() - after).strftime("%Y-%m-%d %X")
        print(f"No log entries found since {ts}")
        return

    # Print the log events
    for event in found:
        ts = event["datetime"].strftime("%Y-%m-%d %X")
        print(f"{event['priority']}: {ts}: {event['method_name']} {event['message']}")


# Main entrance here...
if __name__ == '__main__':
    main()
