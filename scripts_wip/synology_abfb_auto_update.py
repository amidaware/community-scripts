#!/usr/bin/env python3
# Copyright 2022, Nice Guy IT, LLC. All rights reserved.
# SPDX-License-Identifier: MIT
# Source: https://github.com/NiceGuyIT/synology_abfb_log_parser

################################################################################
# This script is deprecated. Use scripts_wip/all_python_module_manager.py
################################################################################

"""
**IMPORTANT**
This script will install the "synology_abfb_log_parser" Python modules in the TRMM Python distribution.
Use at your own risk. Existing modules are not upgraded.

*Note*: When adding arguments to the script in TRMM, use an equals sign "=" to separate the parameter from the value.
For example, use this:
  --log-level=debug
Do not use this as it generate an error:
  --log-level debug


This example will auto-update the "synology_abfb_log_parser" module. The `auto-upgrade` switch is disabled
in the examples because applications should not auto-update in production unless specifically authorized.
If you're lazy and don't mind an occasional hiccup, add this script as a script check with '--auto-upgrade'
and schedule it to run daily or weekly.

$ python3 trmm-synology_abfb_auto_update.py --help
usage: trmm-synology_abfb_auto_update.py [-h]
                                         [--log-level {debug,info,warning,error,critical}]
                                         [--auto-upgrade]

Parse the Synology Active Backup for Business logs.

optional arguments:
  -h, --help            show this help message and exit
  --log-level {debug,info,warning,error,critical}
                        set log level for the Synology Active Backup for
                        Business module
  --auto-upgrade        auto-upgrade the synology_abfb_log_parser module

"""
import argparse
import logging
import subprocess
import sys
import traceback


def pip_install_upgrade(modules, logger=logging.getLogger(), upgrade=False):
    """
    Install or upgrade the specified Python modules using 'pip install'.
    :param modules: set of modules to install/upgrade
    :param logger: logging instance of the root logger
    :param upgrade: Bool If True, upgrade the modules.
    :return: None
    """
    if not modules:
        return
    required_modules = set(modules)
    try:
        python = sys.executable
        logger.info(f'Installing/upgrading modules: {required_modules}')
        if upgrade:
            subprocess.check_call([python, '-m', 'pip', 'install', '--upgrade', *required_modules], stdout=subprocess.DEVNULL)
        else:
            subprocess.check_call([python, '-m', 'pip', 'install', *required_modules], stdout=subprocess.DEVNULL)
    except subprocess.CalledProcessError as err:
        logger.error(f'Failed to install/upgrade the required modules: {required_modules}')
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)


# Main entrance here...
if __name__ == '__main__':
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Parse the Synology Active Backup for Business logs.')
    parser.add_argument('--log-level', default='info', dest='log_level',
                        choices=['debug', 'info', 'warning', 'error', 'critical'],
                        help='set log level for the Synology Active Backup for Business module')
    parser.add_argument('--auto-upgrade', default=False, action='store_true',
                        help='auto-upgrade the synology_abfb_log_parser module')
    args = parser.parse_args()

    # Change default log level to INFO
    default_log_level = 'INFO'
    if args.log_level:
        default_log_level = args.log_level.upper()
    log_format = '%(asctime)s %(funcName)s(%(lineno)d): %(message)s'
    logging.basicConfig(format=log_format, level=default_log_level)
    top_logger = logging.getLogger()
    top_logger.setLevel(default_log_level)

    if args.auto_upgrade:
        requirements = {'synology_abfb_log_parser'}
        pip_install_upgrade(**{
            'modules': requirements,
            'logger': top_logger,
            'upgrade': True,
        })

    # Exit success
    exit(0)
