import argparse


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        prog="run_case",
        description="PULPino UVM Test Case Manager",
    )

    # Positional: test spec (file:class chain)
    parser.add_argument(
        "test_spec", nargs="?", default=None,
        help="Test spec: pulpino_uart_test:uart_base_test.tc_uart_tx_single_test",
    )

    # Filtering
    parser.add_argument("--tag", default=None, help="Filter tests by tag")

    # Listing and Cleaning
    parser.add_argument("--list", action="store_true", dest="list_tests",
                        help="List all available tests")
    parser.add_argument("-c", "--clean", action="store_true",
                        help="Clean the test directory and its build directory for specified cases")

    # Execution control
    parser.add_argument("--dry-run", action="store_true",
                        help="Print commands without executing")
    parser.add_argument("-j", type=int, default=10,
                        help="Parallel job count (default: 10)")
    parser.add_argument("--timeout", type=int, default=None,
                        help="Simulation timeout in seconds (default: unlimited)")

    # Output
    parser.add_argument("-o", default="debug",
                        help="Output directory (default: debug)")
    parser.add_argument("-R", "--rename", default=None,
                        help="Rename the test execution directory (only works when running a single test)")

    # Global switches
    parser.add_argument("--cov", action="store_true",
                        help="Enable coverage collection")
    parser.add_argument("--debug", action="store_true",
                        help="Enable debug mode (VCS -debug_access+all)")
    parser.add_argument("--xprop", action="store_true",
                        help="Enable X-propagation")
    parser.add_argument("-d", "--dump", action="store_true",
                        help="Dump waveform (FSDB)")

    # Post actions
    parser.add_argument("--delete_passed_files", action="store_true",
                        help="Delete output files for passed cases (keep results.log)")
    parser.add_argument("--post_cmd", default=None,
                        help="Command to run after all tests complete")

    # Extra plusargs (everything that starts with +)
    parser.add_argument("extra", nargs="*", default=[],
                        help="Extra plusargs to append to simulation")

    args = parser.parse_args(argv)

    # Validate: must have test_spec or --tag or --list
    if not args.test_spec and not args.tag and not args.list_tests:
        parser.error("Must specify test_spec, --tag, or --list")

    return args
