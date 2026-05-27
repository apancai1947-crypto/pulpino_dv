#!/usr/bin/env python3
"""PULPino UVM Test Case Manager — replaces sim/Makefile."""

import os
import sys

# Ensure sim/ is in path for case_manager imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from case_manager.cli import parse_args
from case_manager.discovery import discover, filter_tests
from case_manager.runner import run_all


def resolve_test_spec(all_tests, spec):
    """Resolve a test spec string to a Test class.

    Format: filename:parent.child.target
    The last component is the test name to match.
    """
    if ":" in spec:
        _file_part, class_chain = spec.split(":", 1)
        test_name = class_chain.rsplit(".", 1)[-1]
    else:
        class_chain = spec
        test_name = spec

    if test_name in all_tests:
        return all_tests[test_name]

    for name, cls in all_tests.items():
        if name == class_chain or spec.endswith(name):
            return cls

    return None


def main():
    args = parse_args()
    test_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test")

    # Discover
    discovered = discover(test_dir)
    all_tests = discovered["tests"]

    # --list mode
    if args.list_tests:
        filtered = filter_tests(all_tests, tag=args.tag)
        for name, cls in sorted(filtered.items()):
            tags = ", ".join(getattr(cls, "tag", []))
            uvm = getattr(cls, "uvm_test", "")
            build_name = cls.build.name if cls.build else "None"
            print(f"  {name:40s}  tags=[{tags}]  uvm={uvm}  build={build_name}")
        print(f"\nTotal: {len(filtered)} tests")
        return

    # Filter tests
    if args.test_spec:
        test_cls = resolve_test_spec(all_tests, args.test_spec)
        if test_cls is None:
            print(f"ERROR: Test not found: {args.test_spec}", file=sys.stderr)
            print(f"Available: {', '.join(sorted(all_tests.keys()))}", file=sys.stderr)
            sys.exit(1)
        tests_to_run = {test_cls.name: test_cls}
    elif args.tag:
        tests_to_run = filter_tests(all_tests, tag=args.tag)
        if not tests_to_run:
            print(f"ERROR: No tests found with tag: {args.tag}", file=sys.stderr)
            sys.exit(1)
    else:
        tests_to_run = all_tests

    # Make output dir absolute (relative to project root, not sim/)
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", args.o))

    # Clean
    if args.clean:
        import shutil
        from case_manager.runner import compute_build_hash, get_global_opts
        
        global_vlog_opts, _ = get_global_opts(args)
        
        cleaned_builds = set()
        for test_cls in tests_to_run.values():
            target_name = args.rename if (args.rename and len(tests_to_run) == 1) else test_cls.name
            test_dir = os.path.join(out_dir, target_name)
            if os.path.exists(test_dir):
                shutil.rmtree(test_dir)
                print(f"[CLEAN] Removed test directory: {test_dir}")
                
            build_cls = test_cls.build
            if build_cls:
                build_hash = compute_build_hash(build_cls, global_vlog_opts)
                build_dir = os.path.join(out_dir, f".{build_hash}")
                if build_dir not in cleaned_builds and os.path.exists(build_dir):
                    shutil.rmtree(build_dir)
                    cleaned_builds.add(build_dir)
                    print(f"[CLEAN] Removed build directory: {build_dir}")
        print(f"\n[CLEAN] Done, starting simulation...")

    # Run
    success = run_all(tests_to_run, out_dir, args, args.extra)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
