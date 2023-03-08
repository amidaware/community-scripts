#!/usr/bin/env python3
"""
TODO: Clean up the comments.
**IMPORTANT**
This script will install or update the Python modules in the TRMM Python distribution.
Use at your own risk. Existing modules are not upgraded.

*Note*: When adding arguments to the script in TRMM, use an equals sign "=" to separate the parameter from the value.
For example, use this:
  --log-level=debug
Do not use this as it generate an error:
  --log-level debug


This example will manage the TRMM modules. The `auto-upgrade` switch is disabled
in the examples because applications should not auto-update in production unless specifically authorized.
If you're lazy and don't mind an occasional hiccup, add this script as a script check with '--auto-upgrade'
and schedule it to run daily or weekly.

$ python3 python-module-management.py --help
usage: python-module-management.py [-h]
                                   [--log-level {debug,info,warning,error,critical}]
                                   [--auto-upgrade]

optional arguments:
  -h, --help            show this help message and exit
  --log-level {debug,info,warning,error,critical}
                        set log level

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

def pip_upgrade(logger=logging.getLogger()):
    """
    Upgrade the Python modules using 'pip install --upgrade'.
    :param logger: logging instance of the root logger
    :return: None
    """
    try:
        python = sys.executable
        logger.info(f'Upgrading modules')
        subprocess.check_call([python, '-m', 'pip', 'install', '--upgrade'])
    except subprocess.CalledProcessError as err:
        logger.error(f'Failed to upgrade the required modules')
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)

def pip_modules_list(logger=logging.getLogger()):
    """
    List installed modules.
    :param logger: logging instance of the root logger
    :return: string
    """
    try:
        python = sys.executable
        logger.info(f'Listing modules')
        subprocess.check_call([python, '-m', 'pip', 'list'])
    except subprocess.CalledProcessError as err:
        logger.error(f'Failed to list the installed modules')
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)
    
# Main entrance here...
if __name__ == '__main__':
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Manage the python modules in TRMM.')
    parser.add_argument('--log-level', default='info', dest='log_level',
                        choices=['debug', 'info', 'warning', 'error', 'critical'],
                        help='set log level')
    """
    command = parser.add_subparsers(dest="command")
    install_parser = command.add_parser("install")
    install_parser.add_argument
    list_parser = command.add_parser("list")
    update_parser = command.add_parser("update")
    """
    parser.add_argument('--list', action='store_true', help='list the installed modules')
    parser.add_argument('--install', action='store_true', help='install the specified modules')
    parser.add_argument('--update', default=False, action='store_true',
                        help='update all installed modules')
    args = parser.parse_args()

    # Change default log level to INFO
    default_log_level = 'INFO'
    if args.log_level:
        default_log_level = args.log_level.upper()
    log_format = '%(asctime)s %(funcName)s(%(lineno)d): %(message)s'
    logging.basicConfig(format=log_format, level=default_log_level)
    top_logger = logging.getLogger()
    top_logger.setLevel(default_log_level)

    logger=logging.getLogger()
    logger.info(f'Args list: {args}')

    if args.list:
        list = pip_modules_list()
        logger.info("Installed modules: {list}")
    elif args.install:
        requirements = {'ctime'}
        pip_install_upgrade(**{
            'modules': requirements,
            'logger': top_logger,
            'upgrade': True,
        })
    elif args.update:
        requirements = {}
        pip_upgrade(**{
            'logger': top_logger,
        })

    # Exit success
    exit(0)