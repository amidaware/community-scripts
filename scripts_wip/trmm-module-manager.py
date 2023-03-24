#!/usr/bin/env python3.10

__name__ = "trmm-module-manager.py"
__version__ = "0.1.0"
__license__ = "MIT"
__authors__ = "NiceGuyIT, silversword411"

"""
**IMPORTANT**
This script will install, uninstall, upgrade or list Python modules in the TRMM Python distribution.
Use at your own risk. Existing modules are not upgraded.

*Note*: When adding arguments to the script in TRMM, use an equals sign "=" to separate the parameter from the value.
For example, use this:
  --log-level=debug
Do not use this as it generate an error:
  --log-level debug

Commands
--------

** List the installed Python modules

    python trmm-module-manager.py list

This will list all installed Python modules using the default format ("columns"). To use a different format, specify
the "--format" option followed by "columns", "freeze", or "json". For example, to list all installed modules in "freeze"
format, run:

    python trmm-module-manager.py list --format columns
    python trmm-module-manager.py list --format freeze
    python trmm-module-manager.py list --format json

--------

** Install one or more Python modules

    python trmm-module-manager.py install numpy pandas

To install a specific version of a module, append "==<version>" to the module name. For example, to install
version 1.0.0 of numpy and the "pandas" module, run:

    python trmm-module-manager.py install numpy==1.0.0 pandas

--------

** Uninstall one or more Python modules

    python trmm-module-manager.py uninstall numpy pandas

This will uninstall the "numpy" and "pandas" modules using pip. Note that this command will remove all versions of
the specified modules:

    python trmm-module-manager.py uninstall numpy pandas

--------

** Upgrade one or more Python modules

    python trmm-module-manager.py upgrade numpy pandas

This will upgrade the "numpy" and "pandas" modules using pip.

    python trmm-module-manager.py uninstall numpy pandas

--------

$ python3 python-module-management.py --help
usage: trmm-module-manager.py [-h] [--log-level {debug,info,warning,error,critical}] {help,list,install,uninstall,upgrade} ...

Manage the python modules in TRMM.

positional arguments:
  {help,list,install,uninstall,upgrade}
    help                Show this help
    list                List the installed modules
    install             Install the specified modules
    uninstall           Unnstall the specified modules
    upgrade             Upgrade all installed modules

options:
  -h, --help            show this help message and exit
  --log-level {debug,info,warning,error,critical}
                        set log level
"""
import argparse
import logging
import subprocess
import sys
import traceback


def pip_install_modules(modules, logger=logging.getLogger(), upgrade=False):
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
        logger.info(f"Installing/upgrading modules: {required_modules}")
        if upgrade:
            subprocess.check_call(
                [python, "-m", "pip", "install", "--upgrade", *required_modules],
                stdout=subprocess.DEVNULL,
            )
        else:
            subprocess.check_call(
                [python, "-m", "pip", "install", *required_modules],
                stdout=subprocess.DEVNULL,
            )
    except subprocess.CalledProcessError as err:
        if upgrade:
            logger.error(
                f"Failed to install/upgrade the required modules: {required_modules}"
            )
        else:
            logger.error(f"Failed to install the required modules: {required_modules}")
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)


def pip_uninstall_modules(modules, logger=logging.getLogger()):
    """
    Uninstall the specified Python modules using 'pip uninstall'.
    :param modules: set of modules to install/upgrade
    :param logger: logging instance of the root logger
    :return: None
    """
    if not modules:
        return
    required_modules = set(modules)
    try:
        python = sys.executable
        logger.info(f"Uninstalling modules: {required_modules}")
        subprocess.check_call(
            [python, "-m", "pip", "uninstall", "--yes", *required_modules],
            stdout=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError as err:
        logger.error(f"Failed to uninstall the specified modules: {required_modules}")
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)


def pip_upgrade_modules(modules, logger=logging.getLogger()):
    """
    Upgrade the Python modules using 'pip install --upgrade'.
    :param modules: set of modules to install/upgrade
    :param logger: logging instance of the root logger
    :return: None
    """
    if not modules:
        return
    required_modules = set(modules)
    try:
        python = sys.executable
        logger.info(f"Upgrading modules: {required_modules}")
        subprocess.check_call(
            [python, "-m", "pip", "install", "--upgrade", *required_modules]
        )
    except subprocess.CalledProcessError as err:
        logger.error(f"Failed to upgrade the specified modules")
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)


def pip_modules_list(format="columns", logger=logging.getLogger()):
    """
    List installed modules.
    :param format: Format for the list: columns (default), freeze, json
    :param logger: logging instance of the root logger
    :return: string
    """
    try:
        python = sys.executable
        logger.info(f"Listing modules")
        return subprocess.check_output(
            [python, "-m", "pip", "list", "--format", format], universal_newlines=True
        )
    except subprocess.CalledProcessError as err:
        logger.error(f"Failed to list the installed modules")
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)


# Main entrance here...
if __name__ == "__main__":
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Manage the python modules in TRMM.")
    parser.add_argument(
        "--log-level",
        default="info",
        dest="log_level",
        choices=["debug", "info", "warning", "error", "critical"],
        help="set log level",
    )

    subparsers = parser.add_subparsers(dest="command")
    help_parser = subparsers.add_parser("help", help="Show this help")
    help_parser.set_defaults(func=lambda _: parser.print_help())

    list_parser = subparsers.add_parser("list", help="List the installed modules")
    list_parser.add_argument(
        "--format", default="columns", choices=["columns", "freeze", "json"]
    )

    install_parser = subparsers.add_parser(
        "install", help="Install the specified modules"
    )
    install_parser.add_argument("modules", nargs="+")

    uninstall_parser = subparsers.add_parser(
        "uninstall", help="Unnstall the specified modules"
    )
    uninstall_parser.add_argument("modules", nargs="+")

    upgrade_parser = subparsers.add_parser(
        "upgrade", help="Upgrade all installed modules"
    )
    upgrade_parser.add_argument("modules", nargs="+")

    # parser.add_argument_group("list", help="Command to run")
    args = parser.parse_args()

    # Change default log level to INFO
    default_log_level = "INFO"
    if args.log_level:
        default_log_level = args.log_level.upper()
    log_format = "%(asctime)s %(funcName)s(%(lineno)d): %(message)s"
    logging.basicConfig(format=log_format, level=default_log_level)
    top_logger = logging.getLogger()
    top_logger.setLevel(default_log_level)

    logger = logging.getLogger()
    logger.info(f"Args list: {args}")
    logger.info(f"command: {args.command}")

    if sys.version_info[0] < 3 and sys.version_info[1] < 10:
        raise Exception(
            "Python version 3.10 is required. Please upgrade your Python version."
        )

    match args.command:
        case "list":
            module_list = pip_modules_list(
                **{
                    "format": args.format,
                }
            )
            logger.info(f"Installed modules (format: {args.format}):")
            print(module_list)

        case "install":
            logger.info(f"Installing modules: {args.modules}")
            pip_install_modules(
                **{
                    "modules": args.modules,
                    "logger": top_logger,
                    "upgrade": False,
                }
            )

        case "uninstall":
            logger.info(f"Uninstalling modules: {args.modules}")
            pip_uninstall_modules(
                **{
                    "modules": args.modules,
                    "logger": top_logger,
                }
            )

        case "upgrade":
            logger.info(f"Upgrading modules: {args.modules}")
            pip_upgrade_modules(
                **{
                    "modules": args.modules,
                    "logger": top_logger,
                }
            )

        case "help":
            parser.print_help()
            exit(0)

        case _:
            logger.info(f"Invalid command: {args.command}")
            parser.print_usage()
            exit(1)

    # Exit success
    exit(0)
