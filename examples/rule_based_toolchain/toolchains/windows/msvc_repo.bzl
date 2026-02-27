"""Repository rule to read MSVC from the host."""

def _normalize_windows_path(path):
    return path.replace("\\", "/").rstrip("/")

def _detect_vc_root(repository_ctx):
    env = repository_ctx.os.environ
    bazel_vc = env.get("BAZEL_VC", "")
    if bazel_vc:
        return _normalize_windows_path(bazel_vc)

    bazel_vs = env.get("BAZEL_VS", "")
    if bazel_vs:
        return _normalize_windows_path(bazel_vs + "/VC")

    vcinstall_dir = env.get("VCINSTALLDIR", "")
    if vcinstall_dir:
        return _normalize_windows_path(vcinstall_dir)

    vsinstall_dir = env.get("VSINSTALLDIR", "")
    if vsinstall_dir:
        return _normalize_windows_path(vsinstall_dir + "/VC")

    return None

def _is_vs_2017_or_newer(repository_ctx, vc_root):
    return repository_ctx.path(vc_root).get_child("Tools").exists

def _find_vcvars_bat_script(repository_ctx, vc_root):
    if _is_vs_2017_or_newer(repository_ctx, vc_root):
        vcvars_script = vc_root + "/Auxiliary/Build/VCVARSALL.BAT"
    else:
        vcvars_script = vc_root + "/VCVARSALL.BAT"

    if not repository_ctx.path(vcvars_script).exists:
        return None

    return vcvars_script

def _latest_msvc_root(repository_ctx, msvc_root):
    msvc_root = _normalize_windows_path(msvc_root)
    if repository_ctx.path(msvc_root + "/bin").exists:
        return msvc_root

    tools_root = msvc_root + "/Tools/MSVC"
    tools_path = repository_ctx.path(tools_root)
    if not tools_path.exists:
        return None

    versions = [path.basename for path in tools_path.readdir()]
    version_list = []
    for version in versions:
        parts = version.split(".")
        if not all([part.isdigit() for part in parts]):
            continue
        version_list.append(([int(part) for part in parts], version))
    if not version_list:
        return None

    version_list = sorted(version_list)
    return tools_root + "/" + version_list[-1][1]

def _detect_target_arch(repository_ctx):
    arch = repository_ctx.os.environ.get("PROCESSOR_ARCHITECTURE", "").lower()
    if arch in ["amd64", "x86_64"]:
        return struct(
            target_arch = "x64",
            ml_name = "ml64.exe",
            host_order = ["HostX64", "HostX86"],
        )
    elif arch in ["x86"]:
        return struct(
            target_arch = "x86",
            ml_name = "ml.exe",
            host_order = ["HostX86", "HostX64"],
        )
    elif arch in ["arm64", "aarch64"]:
        return struct(
            target_arch = "arm64",
            ml_name = "ml64.exe",
            host_order = ["HostX64", "HostX86"],
        )
    else:
        return struct(
            target_arch = "",
            ml_name = "ml.exe",
            host_order = ["HostX64", "HostX86"],
        )

def _msvc_bin_dirs(repository_ctx, msvc_root, target_arch, host_order):
    if not target_arch:
        return []

    if (repository_ctx.path(msvc_root + "/bin/HostX64").exists or
        repository_ctx.path(msvc_root + "/bin/HostX86").exists):
        return [msvc_root + "/bin/" + host + "/" + target_arch for host in host_order]
    return []

def _read_vcvars_env(repository_ctx, arch_info):
    vc_root = _detect_vc_root(repository_ctx)
    if not vc_root:
        fail("Failed to locate VC root for arch '{}'.".format(arch_info.target_arch))

    msvc_root = _latest_msvc_root(repository_ctx, vc_root)
    if not msvc_root:
        fail("Failed to locate MSVC root for arch '{}'.".format(arch_info.target_arch))

    vcvars_script = _find_vcvars_bat_script(repository_ctx, vc_root)
    if not vcvars_script:
        fail("Failed to locate VCVARSALL.BAT under '{}'.".format(vc_root))

    if arch_info.target_arch == "x64":
        arch_arg = "amd64"
    elif arch_info.target_arch == "x86":
        arch_arg = "x86"
    elif arch_info.target_arch == "arm64":
        arch_arg = "amd64_arm64"
    else:
        arch_arg = "amd64"

    repository_ctx.file(
        "get_env.bat",
        "@echo off\n" +
        "call \"" + vcvars_script.replace("/", "\\") + "\" " + arch_arg + " > NUL\n" +
        "echo INCLUDE=%INCLUDE%\n" +
        "echo LIB=%LIB%\n" +
        "echo PATH=%PATH%\n",
        True,
    )
    output = repository_ctx.execute(["./get_env.bat"])

    if output.return_code:
        fail("Failed to run VCVARSALL.BAT (exit {}).".format(output.return_code))

    env = {}
    for raw in output.stdout.splitlines():
        if "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        env[key] = value
    return struct(env = env, vc_root = vc_root, msvc_root = msvc_root)

def _write_build(repository_ctx, ml_name, has_bins):
    cl_srcs = ["bin/cl.exe"] if has_bins else []
    link_srcs = ["bin/link.exe"] if has_bins else []
    lib_srcs = ["bin/lib.exe"] if has_bins else []
    ml_srcs = ["bin/{}".format(ml_name)] if has_bins else []
    exports = cl_srcs + link_srcs + lib_srcs + ml_srcs

    repository_ctx.file(
        "BUILD.bazel",
        "\n".join([
            "package(default_visibility = [\"//visibility:public\"])",
            "",
            "filegroup(",
            "    name = \"cl\",",
            "    srcs = {},".format(repr(cl_srcs)),
            ")",
            "filegroup(",
            "    name = \"link\",",
            "    srcs = {},".format(repr(link_srcs)),
            ")",
            "filegroup(",
            "    name = \"lib\",",
            "    srcs = {},".format(repr(lib_srcs)),
            ")",
            "filegroup(",
            "    name = \"ml\",",
            "    srcs = {},".format(repr(ml_srcs)),
            ")",
            "exports_files({})".format(repr(exports)),
            "",
        ]),
    )

def _write_paths(repository_ctx, include_paths, lib_paths, msvc_path):
    repository_ctx.file(
        "paths.bzl",
        "INCLUDE_PATHS = {}\nLIB_PATHS = {}\nMSVC_PATH = {}\n".format(
            repr(include_paths),
            repr(lib_paths),
            repr(msvc_path),
        ),
    )

def _windows_msvc_impl(repository_ctx):
    if not repository_ctx.os.name.startswith("windows"):
        _write_paths(repository_ctx, [], [], "")
        _write_build(repository_ctx, "ml.exe", False)
        return

    arch_info = _detect_target_arch(repository_ctx)
    vcvars = _read_vcvars_env(repository_ctx, arch_info)
    env = vcvars.env

    include_paths = []
    include_env = env.get("INCLUDE", "")
    if include_env:
        for raw in include_env.split(";"):
            raw = raw.strip()
            if not raw:
                continue
            include_paths.append(raw.replace("\\", "/"))
    if not include_paths:
        fail("Failed to locate INCLUDE paths via VCVARSALL.BAT.")

    resource_label = None
    if arch_info.target_arch == "x64":
        resource_label = repository_ctx.attr.clang_resource_header_x86_64
    elif arch_info.target_arch == "arm64":
        resource_label = repository_ctx.attr.clang_resource_header_aarch64
    if resource_label:
        resource_path = repository_ctx.path(Label(resource_label))
        if resource_path.exists:
            include_paths.append(str(resource_path.dirname).replace("\\", "/"))

    lib_paths = []
    lib_env = env.get("LIB", "")
    if lib_env:
        for raw in lib_env.split(";"):
            raw = raw.strip()
            if not raw:
                continue
            lib_paths.append(raw.replace("\\", "/"))
    if not lib_paths:
        fail("Failed to locate LIB paths via VCVARSALL.BAT.")

    msvc_root = vcvars.msvc_root

    bin_dirs = _msvc_bin_dirs(repository_ctx, msvc_root, arch_info.target_arch, arch_info.host_order)
    bin_dir = None
    for candidate in bin_dirs:
        if repository_ctx.path(candidate).exists:
            bin_dir = candidate
            break
    if not bin_dir:
        fail("Failed to locate MSVC bin directory for arch '{}'.".format(arch_info.target_arch))

    repository_ctx.symlink(bin_dir, "bin")

    msvc_bins = []
    for path in bin_dirs:
        if repository_ctx.path(path).exists:
            msvc_bins.append(path.replace("\\", "/"))
    if not msvc_bins:
        fail("Failed to locate MSVC bin directories under '{}'.".format(msvc_root))

    path_env = repository_ctx.os.environ.get("PATH", "")
    vc_path_env = env.get("PATH", "")
    joined = ";".join(msvc_bins + ([vc_path_env] if vc_path_env else []) + ([path_env] if path_env else []))

    _write_paths(repository_ctx, include_paths, lib_paths, joined)
    _write_build(repository_ctx, arch_info.ml_name, True)

windows_msvc = repository_rule(
    implementation = _windows_msvc_impl,
    attrs = {
        "clang_resource_header_x86_64": attr.string(),
        "clang_resource_header_aarch64": attr.string(),
    },
    environ = [
        "BAZEL_VC",
        "BAZEL_VS",
        "PATH",
        "PROCESSOR_ARCHITECTURE",
        "VCINSTALLDIR",
        "VSINSTALLDIR",
    ],
)
