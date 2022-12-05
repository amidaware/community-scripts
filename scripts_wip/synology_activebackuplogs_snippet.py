# Version: 0.1.0
# Author: David Randall
# GitHUb: github.com/NiceGuyIT
# URL: NiceGuyIT.biz
# License: MIT
#
# Parse Synology Active Backup for Business log files
# This is a Python script that will parse the Synology Active Backup for Business log files, allow you to search them,
# and return the results. Some examples are provided. The code is commented to explain what's needed.
#
# IMPORTANT: This snippet will install some Python modules in the TRMM Python distribution. Use at your own risk.
# Existing modules are not upgraded.
#
# How to use:
# `synology_activebackuplogs_snippet.py` is a TRMM snippet. Add it to your snippet library.
# Keep the name "synology_activebackuplogs_snippet.py".
# Add one of the examples to your script library. Run it on an endpoint that has Synology Active Backup installed.
# Read the comments to understand what can/should be changed to suit your needs.
#
# References:
#   - [Synology Active Backup for Business][1]
#   - [Future enhancement might be to use the Synology API][2]
# [1]: https://kb.synology.com/en-br/DSM/help/ActiveBackup/activebackup_business_activities?version=7
# [2]: https://github.com/N4S4/synology-api
#
import json
import os.path
import pkg_resources
import re
import subprocess
import sys


def install(*modules):
    """
    Install the required Python modules if they are not installed.
    See https://stackoverflow.com/a/44210735
    Search for modules: https://pypi.org/
    :param modules: list of required modules
    :return: None
    """
    if not modules:
        return
    required = set(modules)
    installed = {pkg.key for pkg in pkg_resources.working_set}
    missing = required - installed

    if missing:
        print(f"Installing modules:", *missing)
        try:
            python = sys.executable
            subprocess.check_call([python, '-m', 'pip', 'install', *missing], stdout=subprocess.DEVNULL)
        except subprocess.CalledProcessError as err:
            print(f"Failed to install the required modules: {missing}")
            print(err)
            exit(1)


try:
    import datetime
    import glob
    import pyparsing
except ModuleNotFoundError:
    req = {"datetime", "glob2", "pyparsing"}
    if sys.platform == "win32":
        install(*req)
    else:
        print(f"Required modules are not installed: {req}")
        print("Automatic module installation is supported only on Windows")
        exit(1)


def fix_single_quotes(json_str):
    """
    fix_single_quotes will replace JSON-type strings containing double quotes with single quotes to make the entire
    string valid JSON.

    Example:
    Given the string
        "task_template": {"backup_cache_content": "{"cached_enabled":false}"}
    the double quotes inside "{...}" will be replaced with single quotes resulting in
        "task_template": {"backup_cache_content": "{'cached_enabled':false}"}

    :param json_str: json_str
    :return cleaned: string
    """
    if not json_str:
        return json_str

    re_left = re.compile(r'"\{')
    re_right = re.compile(r'}"')
    left = re.split(re_left, json_str)
    if not left:
        return json_str

    cleaned = ""
    for index, val in enumerate(left):
        if index == 0:
            # The first value is valid JSON.
            cleaned = val
            continue

        # The right should split into only 2 pieces
        right = re.split(re_right, val)
        if len(right) != 2:
            print("Could not fix JSON with single quotes")
            print(f"JSON string: {json_str}")
            print(f"left: {left}")
            print(f"right: {right}")
            return json_str

        # The first piece is invalid and needs double quotes replaced with single quotes.
        # The second piece is valid JSON
        cleaned += '"{' + right[0].replace('"', "'") + '}"' + right[1]

    return cleaned


def fix_simple(json_str):
    """
    fix_simple will perform simple replacements to fix invalid JSON strings.

    Example:
    Given the string
        "snapshot_info": {"data_length": 18739, }, "subaction": "update_device_spec"
    the ", }" will be replaced with "}" resulting in
        "snapshot_info": {"data_length": 18739}, "subaction": "update_device_spec"

    Given the string
        "volume_name": "\\?\Volume{12345678-1234-abcd-1234-12345678abcd}\"},
    the backslashes are escaped with a backslash resulting in
        "volume_name": "\\\\?\\Volume{12345678-1234-abcd-1234-12345678abcd}\\"},

    :param json_str: json_str
    :return cleaned: string
    """
    if not json_str:
        return json_str
    return json_str.replace(', }', '}').replace('\\', '\\\\')


class SynologyActiveBackupLogs(object):
    """
    SynologyActiveBackupLogs will consume Synology Active Backup logs, parse them and make them available for searching.
    """

    def __init__(self, after=datetime.timedelta(days=365), log_path=None, filename_glob=None):
        """
        Initialize class parameters.

        :param after: datetime.timedelta of how far back to search.
        :param log_path: string path to the log files
        :param filename_glob: string filename glob pattern for the log files
        """
        # Filename glob for logs
        self.__log_filename_glob = "log.txt*"
        if filename_glob:
            self.__log_filename_glob = filename_glob

        # Path to log files
        self.__log_path = None
        if sys.platform == "linux" or sys.platform == "linux2":
            # FIXME: Is this the correct path?
            self.__log_path = "/var/log/activebackupforbusinessagent"
        elif sys.platform == "darwin":
            # FIXME: Is this the correct path?
            self.__log_path = "/var/log/activebackupforbusinessagent"
        elif sys.platform == "win32":
            self.__log_path = 'C:\\ProgramData\\ActiveBackupForBusinessAgent\\log'
        # Log path was provided
        if log_path:
            self.__log_path = log_path

        # __re_timestamp is a regular expression to extract the timestamp from the beginning of the logs.
        self.__re_timestamp = re.compile(r'^(?P<month>\w{3}) (?P<day>\d+) (?P<time>[\d:]{8})')

        # __re_everything is a regular expression to match the rest of the log message
        self.__re_everything = re.compile(r'.*')

        # __now is a timestamp used to determine if the log entry is after "now". 1 minute is added for
        # processing time.
        self.__now = datetime.datetime.now() + datetime.timedelta(minutes=1)

        # __current_year is the current year and used to determine if the log entry is for this year or last year.
        # The logs do not contain the year.
        self.__current_year = self.__now.year

        # __after is a timestamp used to calculate if the log should be included in the search
        # Default: 1 year ago (365 days)
        if after:
            self.__after = after

        # __lines is an array of the log entries in the log file, one log entry per "line".
        self.__lines = []

        # __lines_ts is the timestamp for the corresponding line. The numerical offset needs to be kept in sync with
        # the lines.
        self.__lines_ts = []

        # __events is an array of the log entries that match the search criteria.
        self.__events = []

        # https://pyparsing-docs.readthedocs.io/en/latest/HowToUsePyparsing.html#usage-notes
        # Alias to improve readability
        numbers = pyparsing.Word(pyparsing.nums)

        # Timestamp at the beginning of the log entry
        # Format: Mon DD HH:MM:SS
        month = pyparsing.Word(pyparsing.string.ascii_uppercase, pyparsing.string.ascii_lowercase, exact=3)
        day = numbers
        hour = pyparsing.Combine(numbers + ":" + numbers + ":" + numbers)
        timestamp = pyparsing.Combine(month + pyparsing.White() +
                                      day + pyparsing.White() +
                                      hour).setResultsName("timestamp")

        # Priority of the log entry
        # Format: [INFO]
        level = pyparsing.Word(pyparsing.string.ascii_uppercase).setResultsName("priority")
        priority = pyparsing.Suppress("[") + level + pyparsing.Suppress("]")

        # Method name from the calling program
        # Format: server-requester.cpp
        method_name = pyparsing.Word(pyparsing.alphas + pyparsing.nums + "_" + "-" + ".").setResultsName("method_name")

        # Method line number from the calling program
        # Format: (68):
        method_num = pyparsing.Suppress("(") + numbers.setResultsName("method_num") + pyparsing.Suppress("):")

        # Message that is logged
        # The format has no rhyme or reason. Some entries have JSON payloads. Some just have words. Some entries span
        # multiple lines. The method name and line number can be used to determine the format type, but the line
        # number may change in each release.
        message = pyparsing.Regex(self.__re_everything, flags=re.DOTALL).setResultsName("message")

        # Pattern to parse a log entry
        self.__pattern = timestamp + priority + method_name + method_num + message

    def parse(self, log=None, log_ts=None):
        """
        Parse will parse the log entry into its component parts.

        :param log: string
        :param log_ts: datetime.datetime
        :return: None if there was a ParseException. dict of the parsed log.
        """
        try:
            parsed = self.__pattern.parseString(log)
        except pyparsing.ParseException as err:
            print("Failed to parse log entry")
            print(log)
            print(err.explain(err, depth=5))
            return None

        payload = {
            "datetime": log_ts,
            "timestamp": parsed["timestamp"],
            "priority": parsed["priority"],
            "method_name": parsed["method_name"],
            "method_num": parsed["method_num"],
            "message": parsed["message"],
            "json_str": None,
            "json": None,
        }

        # Ignore strings that look like JSON but aren't. This is to prevent false JSON parsing errors.
        # FIXME: Convert this be a set.
        re_ignore_list = [
            re.compile(r'getVolumeDetailInfo for .*Volume'),
            re.compile(r'Snapshot: \{'),
            re.compile(r'Create snapshot for'),
        ]
        for regex in re_ignore_list:
            matches = re.search(regex, payload["message"])
            if matches:
                # print(f"Ignoring fake JSON: {payload['message']}")
                # print(f"matches: {matches}")
                # Fake JSON found. Don't continue the search.
                return payload

        # If the message has what looks like JSON, extract it from the payload.
        re_list = [
            re.compile(r"'(?P<json>{.*})'"),
            re.compile(r'([^{]*)(?P<json>\{".*})(.*)'),
        ]
        for regex in re_list:
            matches = re.search(regex, payload["message"])
            if matches:
                # Fix single quotes
                # Fix commas without values
                payload["json_str"] = fix_simple(fix_single_quotes(matches["json"]))
                try:
                    payload["json"] = json.loads(payload["json_str"], strict=False)
                    # print("JSON Object:", payload["json"])
                    # Valid JSON found. Don't need to look for more.
                    return payload
                except json.decoder.JSONDecodeError as err:
                    print("ERR: Failed to parse JSON from message")
                    print("Input JSON string:")
                    print(payload["json_str"])
                    print("Input log string:")
                    print(payload["message"])
                    print(log)
                    print(err)
                    print("-----")

        return payload

    def load_log_file(self, log_path):
        """
        log_log_file will iterate over the log files and load the log entries into an object.

        :param log_path: string
        :return: None
        """
        # Use the correct encoding.
        # https://stackoverflow.com/questions/17912307/u-ufeff-in-python-string/17912811#17912811
        #   Note that EF BB BF is a UTF-8-encoded BOM. It is not required for UTF-8, but serves only as a
        #   signature (usually on Windows).
        with open(log_path, mode="r", encoding="utf-8-sig") as fh:
            for line in fh.readlines():
                ts_match = self.__re_timestamp.match(line)
                if ts_match:
                    # New log entry
                    # Check if the timestamp is before the threshold
                    # FIXME: Use f-strings
                    ts = datetime.datetime.strptime("{year} {month} {day} {time}".format(
                        month=ts_match.group("month"),
                        day=ts_match.group("day"),
                        time=ts_match.group("time"),
                        year=self.__current_year,
                    ), "%Y %b %d %X")
                    if self.__now < ts:
                        # Log timestamp is in the future indicating the log entry is from last year. Subtract one year.
                        # FIXME: This does not take into account leap years. It may be off 1 day on leap years.
                        ts = ts - datetime.timedelta(days=365)

                    if self.__now - self.__after < ts:
                        # Log timestamp is after the "after" timestamp. Include it.
                        # Always include the timestamp
                        self.__lines.append(line.strip())
                        self.__lines_ts.append(ts)

                else:
                    # Multiline log entry; append to last line
                    if len(self.__lines) == 0:
                        # Log timestamp was before the "after" window and nothing is captured yet.
                        continue
                    self.__lines[len(self.__lines) - 1] += line.strip()

    def load(self):
        """
        Load will load all the log files in the path.

        :return: None
        """
        if not os.path.isdir(self.__log_path):
            print(f"Error: Log directory does not exist: {self.__log_path}")
            return None

        files = glob.glob(os.path.join(self.__log_path, self.__log_filename_glob))
        files.sort(key=os.path.getmtime)
        for file in files:
            if datetime.datetime.fromtimestamp(os.path.getmtime(file)) > datetime.datetime.now() - self.__after:
                # print(f"Processing log file: {file}")
                self.load_log_file(file)

        return None

    def search(self, find):
        """
        search will iterate over the log entries searching for lines "after" the window that match the values in find.
        find is required.
        Depth is limited by the code. ObjectPath can query objects and nested structures.
        See https://stackoverflow.com/a/41496646

        :param find: dict representing the log entries to find.
        :return: dict of the log entries.
        """
        for x in range(len(self.__lines)):
            fields = self.parse(log=self.__lines[x], log_ts=self.__lines_ts[x])
            if fields and self.is_subset(find, fields):
                self.__events.append(fields)
        return self.__events

    def is_subset(self, subset, superset):
        """
        is_subset will recursively compare two dictionaries and return true if subset is a subset of the superset.
        See https://stackoverflow.com/a/57675231

        :param subset: dict of the subset
        :param superset: dict of the superset
        :return: true if subset is a subset of the superset
        """
        if subset is None or superset is None:
            return False

        if isinstance(subset, dict):
            return all(key in superset and self.is_subset(val, superset[key]) for key, val in subset.items())

        if isinstance(subset, list) or isinstance(subset, set):
            return all(any(self.is_subset(subitem, superitem) for superitem in superset) for subitem in subset)

        # assume that subset is a plain value if none of the above match
        return subset == superset
