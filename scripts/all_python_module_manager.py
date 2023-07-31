#!/usr/bin/env python3

__version__ = "0.1.2"
__license__ = "MIT"
__authors__ = "NiceGuyIT, silversword411"

"""
**IMPORTANT**
This purpose of this script is to manage modules in a Python install. Tactical installs Python 3.8 on Windows, and does
not install Python on other OS's. When installing modules, this script will use the Tactical installed Python on
Windows, and the first Python 3.x in the `$PATH on Linux and macOS. See the docs[1] for more information.

**Use at your own risk.** Nothing stops you from breaking your Python install.

This script will list, install, uninstall, and upgrade Python modules in the Python installation on the agent. The
Python location and version is provided by the "info" command.

The minimum version of Python supported is 3.8. Older versions are not supported and may generate an error.

*Note*: When adding arguments to the script in TRMM, use an equals sign "=" to separate the parameter from the value.
For example, use this:
  --log-level=debug
Do not use this as it will generate an error:
  --log-level debug

[1]: https://docs.tacticalrmm.com/functions/scripting/#Python
"""

"""
Commands
--------

** List the installed Python modules

    python python_module_manager.py list

This will list all installed Python modules using the default format ("columns"). To use a different format, specify
the "--format" option followed by "columns", "freeze", or "json". For example, to list all installed modules in "freeze"
format, run:

    python python_module_manager.py list --format columns
    python python_module_manager.py list --format freeze
    python python_module_manager.py list --format json

--------

** Check if the Python modules are installed

    python python_module_manager.py check module1 module2

This will check if the Python modules are installed. Use this as a "check" in TRMM to check for necessary modules.
For example, to check if the "dataclasses" (core) and "requests" (non-core) modules are installed, run:

    python python_module_manager.py check dataclassses requests

--------

** Install one or more Python modules

    python python_module_manager.py install numpy pandas

To install a specific version of a module, append "==<version>" to the module name. For example, to install
version 1.0.0 of numpy and the "pandas" module, run:

    python python_module_manager.py install numpy==1.0.0 pandas

--------

** Uninstall one or more Python modules

    python python_module_manager.py uninstall numpy pandas

This will uninstall the "numpy" and "pandas" modules using pip. Note that this command will remove all versions of
the specified modules:

    python python_module_manager.py uninstall numpy pandas

--------

** Upgrade one or more Python modules

    python python_module_manager.py upgrade numpy pandas

This will upgrade the "numpy" and "pandas" modules using pip.

    python python_module_manager.py uninstall numpy pandas

--------

** Get information about the Python location

    python python_module_manager.py info

This will list the install location of the Python modules. Add --verbose to output more information.
  - Note: In Python terms, the module location is called "site-packages".

    python python_module_manager.py info
    python python_module_manager.py info --verbose

--------

$ python3 python-module-management.py --help
usage: python_module_manager.py [-h] [--log-level {debug,info,warning,error,critical}] {help,info,list,install,uninstall,upgrade} ...

Manage the python modules in TRMM.

positional arguments:
  {help,info,list,install,uninstall,upgrade}
    help                Show this help
    info                Get the Python site (system) info
    list                List the installed modules
    install             Install the specified modules
    uninstall           Uninstall the specified modules
    upgrade             Upgrade all installed modules

options:
  -h, --help            show this help message and exit
  --log-level {debug,info,warning,error,critical}
                        set log level
"""
import argparse
import importlib.util
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
        logger.debug(f"Installing/upgrading modules: {required_modules}")
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

def check_modules(modules, logger=logging.getLogger()):
    """

    :param modules: list of modules to check if they are installed
    :type modules: list
    :param logger: Logging instance
    :type logger: logging.Logger
    :return:
    :rtype:
    """
    """
    Install or upgrade the specified Python modules using 'pip install'.
    :param modules: set of modules to install/upgrade
    :param logger: logging instance of the root logger
    :return: None
    """
    if not modules:
        return
    required_modules = set(modules)
    logger.debug(f"Checking modules: {required_modules}")
    ok = True
    try:
        for module in modules:
            # Check if the library exists
            if (spec := importlib.util.find_spec(module)) is not None:
                print(f'Module {module!r} exists in sys.modules')
            else:
                print(f'Module {module!r} was not found in sys.modules')
                ok = False
    except:
        logger.error(f'Failed to check if the required modules are installed. required_modules: {required_modules}')
        logger.error(traceback.format_exc())
        exit(1)

    if not ok:
        print(f'One or more modules were not found. Exiting with failure code.')
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
        logger.debug(f"Uninstalling modules: {required_modules}")
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
        logger.debug(f"Upgrading modules: {required_modules}")
        subprocess.check_call(
            ["python", "-m", "pip", "install", "--upgrade", *required_modules]
        )
    except subprocess.CalledProcessError as err:
        logger.error(f"Failed to upgrade the specified modules")
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)

def pip_modules_list(output_format="columns", logger=logging.getLogger()):
    """
    List installed modules.
    :param output_format: Format for the list: columns (default), freeze, json
    :param logger: logging instance of the root logger
    :return: string
    """
    try:
        python = sys.executable
        logger.debug(f"Listing modules")
        return subprocess.check_output(
            [python, "-m", "pip", "list", "--format", output_format], universal_newlines=True
        )
    except subprocess.CalledProcessError as err:
        logger.error(f"Failed to list the installed modules")
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)

def pip_site_info(verbose=False, logger=logging.getLogger()):
    """
    Get Python site information.
    :param verbose: If true, output more verbose information
    :param logger: logging instance of the root logger
    :return: string
    """
    try:
        python = sys.executable
        logger.debug(f"Python site info")
        if verbose:
            return subprocess.check_output(
                [python, "-m", "site"], universal_newlines=True
            )
        else:
            return subprocess.check_output(
                [python, "-c", "import site; print(site.getsitepackages())"], universal_newlines=True
            )
    except subprocess.CalledProcessError as err:
        logger.error(f"Failed to list the installed modules")
        logger.error(traceback.format_exc())
        logger.error(err)
        exit(1)

def main():
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

    info_parser = subparsers.add_parser("info", help="Get the Python site (system) info")
    info_parser.add_argument("--verbose", action="store_true",
                             help="Output more information about the system installation")
    info_parser.add_argument("--no-verbose", dest="verbose", action="store_false",
                             help="Output less information about the system installation (default)")
    info_parser.set_defaults(verbose=False)

    list_parser = subparsers.add_parser("list", help="List the installed modules")
    list_parser.add_argument("--format", default="columns", choices=["columns", "freeze", "json"],
                             help="Same as python -m pip list --format option")

    check_parser = subparsers.add_parser("check", help="Check if the specified modules are installed")
    check_parser.add_argument("modules", nargs="+",
                                help="A (space separated) list of modules to check")

    install_parser = subparsers.add_parser("install", help="Install the specified modules")
    install_parser.add_argument("modules", nargs="+",
                                help="A (space separated) list of modules to install")

    uninstall_parser = subparsers.add_parser("uninstall", help="Uninstall the specified modules")
    uninstall_parser.add_argument("modules", nargs="+",
                                  help="A (space separated) list of modules to uninstall")

    upgrade_parser = subparsers.add_parser("upgrade", help="Upgrade all installed modules")
    upgrade_parser.add_argument("modules", nargs="+",
                                help="A (space separated) list of modules to upgrade")

    args = parser.parse_args()

    # Change default log level to INFO
    default_log_level = "INFO"
    if args.log_level:
        default_log_level = args.log_level.upper()
    log_format = "%(asctime)s %(levelname)s %(funcName)s(%(lineno)d): %(message)s"
    logging.basicConfig(format=log_format, level=default_log_level)
    top_logger = logging.getLogger()
    top_logger.setLevel(default_log_level)

    logger = logging.getLogger()
    logger.debug(f"Args list: {args}")
    logger.debug(f"command: {args.command}")

    if sys.version_info.major < 3 or (sys.version_info.major == 3 and sys.version_info.minor < 8):
        logger.error("Python version 3.8 or higher is required. Please upgrade your Python version.")
        logger.error(f"Current Python version: {sys.version}")
        exit(1)

    if args.command == "info":
        logger.debug(f"Getting Python site info")
        site_info = pip_site_info(
            **{
                "verbose": args.verbose,
                "logger": top_logger,
            }
        )
        print(site_info)

    elif args.command == "list":
        module_list = pip_modules_list(
            **{
                "output_format": args.format,
            }
        )
        logger.debug(f"Installed modules (format: {args.format}):")
        print(module_list)

    elif args.command == "check":
        logger.debug(f"Checking modules: {args.modules}")
        check_modules(
            **{
                "modules": args.modules,
                "logger": top_logger,
            }
        )

    elif args.command == "install":
        logger.debug(f"Installing modules: {args.modules}")
        pip_install_modules(
            **{
                "modules": args.modules,
                "logger": top_logger,
                "upgrade": False,
            }
        )

    elif args.command == "uninstall":
        logger.debug(f"Uninstalling modules: {args.modules}")
        pip_uninstall_modules(
            **{
                "modules": args.modules,
                "logger": top_logger,
            }
        )

    elif args.command == "upgrade":
        logger.debug(f"Upgrading modules: {args.modules}")
        pip_upgrade_modules(
            **{
                "modules": args.modules,
                "logger": top_logger,
            }
        )

    elif args.command == "help":
        parser.print_help()

    else:
        logger.debug(f"Invalid command: {args.command}")
        parser.print_usage()
        exit(1)


# Main entrance here...
if __name__ == '__main__':
    main()

    # Exit success
    exit(0)
