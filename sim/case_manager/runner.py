import hashlib
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed


def compute_build_hash(build_cls, global_opts=""):
    """Compute hash from vlog_opt + elab_opt + simulator + global_opts."""
    content = f"{build_cls.vlog_opt}|{build_cls.elab_opt}|{build_cls.simulator}|{global_opts}"
    return hashlib.md5(content.encode()).hexdigest()[:8]


def _build_incdir_opts(proj_root):
    """Build +incdir+ options for VCS from project root."""
    pulp_root = os.path.join(proj_root, "repo", "pulpino")
    svt_uart_dir = "/opt/sv_pkgs/uvm/svt_2018.09/svt_uart"
    svt_spi_dir  = "/opt/sv_pkgs/uvm/svt_2018.09/svt_spi"
    svt_i2c_dir  = "/opt/sv_pkgs/uvm/svt_2018.09/svt_i2c"
    dirs = [
        os.path.join(svt_uart_dir, "include", "verilog"),
        os.path.join(svt_uart_dir, "include", "sverilog"),
        os.path.join(svt_uart_dir, "src", "verilog", "vcs"),
        os.path.join(svt_uart_dir, "src", "sverilog", "vcs"),
        os.path.join(svt_spi_dir, "include", "verilog"),
        os.path.join(svt_spi_dir, "include", "sverilog"),
        os.path.join(svt_spi_dir, "src", "verilog", "vcs"),
        os.path.join(svt_spi_dir, "src", "sverilog", "vcs"),
        os.path.join(svt_i2c_dir, "include", "verilog"),
        os.path.join(svt_i2c_dir, "include", "sverilog"),
        os.path.join(svt_i2c_dir, "src", "verilog", "vcs"),
        os.path.join(svt_i2c_dir, "src", "sverilog", "vcs"),
        os.path.join(pulp_root, "rtl", "includes"),
        os.path.join(pulp_root, "tb"),
        os.path.join(proj_root, "tb"),
        os.path.join(proj_root, "tb", "env"),
        os.path.join(proj_root, "tests"),
        os.path.join(proj_root, "seq_lib"),
        os.path.join(pulp_root, "ips", "riscv", "include"),
        os.path.join(pulp_root, "ips", "zero-riscy", "include"),
        os.path.join(pulp_root, "ips", "apb", "apb_event_unit", "include"),
        os.path.join(pulp_root, "ips", "apb", "apb_i2c"),
        os.path.join(pulp_root, "ips", "adv_dbg_if", "rtl"),
        os.path.join(pulp_root, "ips", "axi", "axi_node"),
    ]
    return " ".join(f"+incdir+{d}" for d in dirs if os.path.isdir(d))


def get_global_opts(args):
    """Build global option strings from CLI args for vlog and sim."""
    vlog_opts = []
    sim_opts = []

    if args.cov:
        vlog_opts.append("-cm line+cond+fsm+branch+tgl +define+COV")
        sim_opts.append("-cm line+cond+fsm+branch+tgl")
    if args.debug:
        vlog_opts.append("-debug_access+all -kdb -lca")
    if args.xprop:
        vlog_opts.append("-xprop=tmerge")
    if args.dump:
        vlog_opts.append("-debug_access+all -kdb -lca -fsdb +define+FSDB_DUMP")

    return " ".join(vlog_opts), " ".join(sim_opts)


def compile_build(build_cls, out_dir, global_vlog_opts, dry_run=False, dump=False):
    """Compile a Build, return path to simv directory."""
    build_hash = compute_build_hash(build_cls, global_vlog_opts)
    build_dir = os.path.join(out_dir, f".{build_hash}")

    simv_path = os.path.join(build_dir, "simv")
    if os.path.exists(simv_path):
        print(f"[BUILD] Reusing cached build .{build_hash} ({build_cls.name})")
        return build_dir

    os.makedirs(build_dir, exist_ok=True)

    # VCS must run from project root (filelist uses relative paths)
    proj_root = os.path.normpath(os.path.join(out_dir, ".."))
    incdir_opts = _build_incdir_opts(proj_root)
    vlog_opts = f"{build_cls.vlog_opt} {incdir_opts} {global_vlog_opts}".strip()
    elab_opts = build_cls.elab_opt.strip()

    sim_dir = os.path.join(proj_root, "sim")
    filelist = os.path.join(sim_dir, "filelist.f")

    env_prefix = ""
    if dump:
        env_prefix = "VERDI_HOME=/usr/synopsys/vc_static-O-2018.09-SP2-2/verdi "
    cmd = (
        f"cd {proj_root} && "
        f"{env_prefix}"
        f"vcs {vlog_opts} {elab_opts} "
        f"-Mdir={build_dir}/csrc "
        f"-f {filelist} "
        f"-top tb_top "
        f"-o {build_dir}/simv "
        f"-l {build_dir}/compile.log"
    )

    if dry_run:
        print(f"[DRY-RUN] {cmd}")
        return build_dir

    print(f"[BUILD] Compiling .{build_hash} ({build_cls.name})...")
    print(f"[DEBUG] cmd: {cmd}")
    print(f"[DEBUG] LM_LICENSE_FILE={os.environ.get('LM_LICENSE_FILE', 'NOT SET')}")
    print(f"[DEBUG] VCS_HOME={os.environ.get('VCS_HOME', 'NOT SET')}")
    print(f"[DEBUG] DESIGNWARE_HOME={os.environ.get('DESIGNWARE_HOME', 'NOT SET')}")
    sys.stdout.flush()
    try:
        result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, universal_newlines=True,
                                timeout=600)
    except subprocess.TimeoutExpired:
        print(f"[BUILD] TIMEOUT .{build_hash} ({build_cls.name})", file=sys.stderr)
        raise RuntimeError(f"Build timed out: {build_cls.name}")
    print(f"[DEBUG] VCS returncode={result.returncode}")
    sys.stdout.flush()
    if result.returncode != 0:
        print(f"[BUILD] FAILED .{build_hash}:\n{result.stderr}", file=sys.stderr)
        raise RuntimeError(f"Build failed: {build_cls.name}")

    print(f"[BUILD] Done .{build_hash} ({build_cls.name})")
    return build_dir


def validate_sim_opt(sim_opt):
    """Check sim_opt for forbidden +define+ macros. Return cleaned string."""
    warnings = []
    parts = []
    for opt in sim_opt.split():
        if opt.startswith("+define+"):
            warnings.append(f"WARNING: +define+ not allowed in sim_opt, ignored: {opt}")
        else:
            parts.append(opt)
    return " ".join(parts), warnings


def run_test(test_cls, build_dir, out_dir, global_sim_opts, extra_opts,
             dry_run=False, delete_passed=False, dump=False, rename_dir=None,
             timeout_sec=None, stream_output=False):
    """Run a single test case.

    Returns: (test_name, "PASS"|"FAIL", message)
    """
    test_name = test_cls.name
    test_dir = os.path.join(out_dir, rename_dir if rename_dir else test_name)
    os.makedirs(test_dir, exist_ok=True)

    # Copy simv and simv.daidir from build to test directory
    if not dry_run:
        for item in ["simv", "simv.daidir"]:
            src = os.path.join(build_dir, item)
            dst = os.path.join(test_dir, item)
            if not os.path.exists(src):
                continue
            if os.path.isdir(src):
                if os.path.exists(dst):
                    shutil.rmtree(dst)
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

    # Prerun
    prerun = test_cls.get_prerun_script(out_dir)
    if prerun:
        if dry_run:
            print(f"[DRY-RUN] [{test_name}] prerun: {prerun}")
        else:
            print(f"[SIM] [{test_name}] Running prerun...")
            result = subprocess.run(prerun, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
            if result.returncode != 0:
                return (test_name, "FAIL", f"prerun failed: {result.stderr[:200]}")

    # Validate sim_opt
    sim_opt_clean, warns = validate_sim_opt(test_cls.sim_opt)
    for w in warns:
        print(f"[SIM] [{test_name}] {w}")

    # Build sim command
    uvm_test_arg = f"+UVM_TESTNAME={test_cls.uvm_test}" if test_cls.uvm_test else ""
    fw_dir = os.path.join(test_dir, "fw")
    fw_opts = ""
    if os.path.isdir(fw_dir):
        fw_opts = f"+FW_SLMS={fw_dir}/l2_stim.slm +FW_SLMD={fw_dir}/tcdm_bank0.slm"
    dump_opts = ""
    if dump:
        dump_opts = f"+DUMP_WAVE +FSDB_FILE={test_dir}/novas.fsdb"
    sim_cmd = (
        f"cd {test_dir} && "
        f"DESIGNWARE_HOME=/usr/Synopsys/vip_2018_09 "
        f"./simv +DESIGNWARE_HOME=/usr/Synopsys/vip_2018_09 "
        f"{sim_opt_clean} "
        f"{uvm_test_arg} "
        f"{fw_opts} "
        f"{global_sim_opts} "
        f"{dump_opts} "
        f"{' '.join(extra_opts)} "
        f"-l simv.log"
    )

    if dry_run:
        print(f"[DRY-RUN] [{test_name}] sim: {sim_cmd}")
        return (test_name, "DRY-RUN", "")

    print(f"[SIM] [{test_name}] Running simulation...")
    log_path = os.path.join(test_dir, "simv.log")
    # Remove stale log to avoid误读旧结果
    if os.path.exists(log_path):
        os.remove(log_path)

    proc = subprocess.Popen(sim_cmd, shell=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, universal_newlines=True)

    # Poll simv.log for completion; kill process once done
    # VCS simv may become a zombie after $finish, so we monitor the log
    status = "FAIL"
    msg = ""
    elapsed = 0
    log_pos = 0

    while True:
        if timeout_sec is not None and elapsed >= timeout_sec:
            print(f"\n[SIM] [{test_name}] TIMEOUT ({timeout_sec}s), killing simulation process...")
            proc.kill()
            proc.wait()
            msg = "simulation timed out"
            break

        ret = proc.poll()
        
        # Read new log content if it exists
        log_content = ""
        if os.path.exists(log_path):
            with open(log_path, "r") as f:
                if stream_output:
                    f.seek(log_pos)
                    new_data = f.read()
                    if new_data:
                        sys.stdout.write(new_data)
                        sys.stdout.flush()
                        log_pos = f.tell()
                f.seek(0)
                log_content = f.read()

        if ret is not None:
            break

        if "========== TEST PASSED ==========" in log_content or \
           "========== TEST FAILED ==========" in log_content or \
           "$finish" in log_content:
            if stream_output:
                print(f"\n[SIM] [{test_name}] Finished (detected in log), killing simulation process...")
            else:
                print(f"[SIM] [{test_name}] Finished (detected in log), killing simulation process...")
            proc.kill()
            proc.wait()
            break

        time.sleep(1)
        elapsed += 1

    # Determine pass/fail from log
    if os.path.exists(log_path):
        with open(log_path) as f:
            log_content = f.read()
        if "========== TEST PASSED ==========" in log_content:
            status = "PASS"
        elif "========== TEST FAILED ==========" in log_content:
            status = "FAIL"
            if not msg:
                msg = "UVM reported FAIL"
        elif "$finish" in log_content:
            status = "FAIL"
            if not msg:
                msg = "simulation ended without PASS/FAIL marker"
    else:
        msg = "simv.log not found"

    # Postrun
    postrun = test_cls.postrun_script
    if postrun:
        postrun = postrun.replace("{name}", test_name)
        if dry_run:
            print(f"[DRY-RUN] [{test_name}] postrun: {postrun}")
        else:
            subprocess.run(postrun, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    # Delete passed files if requested
    if delete_passed and status == "PASS" and not dry_run:
        shutil.rmtree(test_dir)
        print(f"[SIM] [{test_name}] PASSED, cleaned output directory")

    print(f"[SIM] [{test_name}] {status}")
    return (test_name, status, msg)


def run_all(tests_to_run, out_dir, args, extra_opts):
    """Main execution: compile builds, run tests in parallel, write results."""
    os.makedirs(out_dir, exist_ok=True)
    global_vlog_opts, global_sim_opts = get_global_opts(args)

    # Collect unique builds and compile
    build_cache = {}
    for test_cls in tests_to_run.values():
        build_cls = test_cls.build
        if build_cls is None:
            print(f"[WARN] Test {test_cls.name} has no build, skipping")
            continue
        if build_cls not in build_cache:
            build_dir = compile_build(build_cls, out_dir, global_vlog_opts,
                                      dry_run=args.dry_run, dump=args.dump)
            build_cache[build_cls] = build_dir

    # Run tests
    results = []
    if args.dry_run:
        for test_cls in tests_to_run.values():
            build_dir = build_cache.get(test_cls.build)
            if build_dir:
                rename_dir = args.rename if (args.rename and len(tests_to_run) == 1) else None
                r = run_test(test_cls, build_dir, out_dir, global_sim_opts,
                             extra_opts, dry_run=True, dump=args.dump, rename_dir=rename_dir,
                             timeout_sec=args.timeout, stream_output=(len(tests_to_run) == 1))
                results.append(r)
    else:
        with ThreadPoolExecutor(max_workers=args.j) as executor:
            futures = {}
            for test_cls in tests_to_run.values():
                build_dir = build_cache.get(test_cls.build)
                if not build_dir:
                    continue
                rename_dir = args.rename if (args.rename and len(tests_to_run) == 1) else None
                future = executor.submit(
                    run_test, test_cls, build_dir, out_dir,
                    global_sim_opts, extra_opts,
                    dry_run=False, delete_passed=args.delete_passed_files,
                    dump=args.dump, rename_dir=rename_dir,
                    timeout_sec=args.timeout, stream_output=(len(tests_to_run) == 1)
                )
                futures[future] = test_cls.name

            for future in as_completed(futures):
                results.append(future.result())

    # Write results.log
    results_path = os.path.join(out_dir, "results.log")
    passed = sum(1 for _, s, _ in results if s == "PASS")
    failed = sum(1 for _, s, _ in results if s == "FAIL")
    with open(results_path, "w") as f:
        f.write(f"Total: {len(results)}  Passed: {passed}  Failed: {failed}\n")
        f.write("-" * 60 + "\n")
        for name, status, msg in results:
            line = f"  {status:6s}  {name}"
            if msg:
                line += f"  ({msg})"
            f.write(line + "\n")

    # Print summary
    print(f"\n{'='*60}")
    print(f"Results: {len(results)} total, {passed} passed, {failed} failed")
    print(f"Log: {results_path}")

    # Post command
    if args.post_cmd and not args.dry_run:
        print(f"\n[POST] Running: {args.post_cmd}")
        subprocess.run(args.post_cmd, shell=True)

    return failed == 0
