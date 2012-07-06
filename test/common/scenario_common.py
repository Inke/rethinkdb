import shlex
import driver
from vcoptparse import *

def prepare_option_parser_mode_flags(opt_parser):
    opt_parser["valgrind"] = BoolFlag("--valgrind")
    opt_parser["valgrind-options"] = StringFlag("--valgrind-options", "--leak-check=full --track-origins=yes")
    opt_parser["mode"] = StringFlag("--mode", "debug")

def parse_mode_flags(parsed_opts):
    mode = parsed_opts["mode"]
    command_prefix = [ ]

    if parsed_opts["valgrind"]:
        command_prefix.append("valgrind")
        for valgrind_option in shlex.split(parsed_opts["valgrind-options"]):
            command_prefix.append(valgrind_option)

        # Make sure we use the valgrind build
        # this assumes that the 'valgrind' substring goes at the end of the specific build string
        if "valgrind" not in mode:
            mode = mode + "-valgrind"

    return driver.find_rethinkdb_executable(mode), command_prefix
