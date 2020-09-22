BAZEL_LIB_ADDITIONAL_PATHS_ENV_VAR = "BAZEL_LIB_ADDITIONAL_PATHS"
BAZEL_LIB_OVERRIDE_PATHS_ENV_VAR = "BAZEL_LIB_OVERRIDE_PATHS"
BAZEL_INCLUDE_ADDITIONAL_PATHS_ENV_VAR = "BAZEL_INCLUDE_ADDITIONAL_PATHS"
BAZEL_INCLUDE_OVERRIDE_PATHS_ENV_VAR = "BAZEL_INCLUDE_OVERRIDE_PATHS"
ENV_VAR_SEPARATOR = ","
ENV_VAR_ASSIGNMENT = "="

def _make_flags(array_of_strings, prefix):
    flags = []
    if array_of_strings:
        for s in array_of_strings:
            flags.append(prefix + s)
    return " ".join(flags)

def _split_env_var(repo_ctx, var_name):
    value = repo_ctx.os.environ.get(var_name)
    if value:
        assignments = value.split(ENV_VAR_SEPARATOR)
        dict = {}
        for assignment in assignments:
            pair = assignment.split(ENV_VAR_ASSIGNMENT)
            if len(pair) != 2:
                fail(
                    "Assignments should have form 'name=value', " +
                    "but encountered {} in env variable {}"
                        .format(assignment, var_name),
                )
            key, value = pair[0], pair[1]
            if not dict.get(key):
                dict[key] = []
            dict[key].append(value)
        return dict
    else:
        return {}

def _get_list_from_env_var(repo_ctx, var_name, key):
    return _split_env_var(repo_ctx, var_name).get(key, default = [])

def _execute_bash(repo_ctx, cmd):
    return repo_ctx.execute(["/bin/bash", "-c", cmd]).stdout.replace("\n", "")

def _find_linker(repo_ctx):
    ld = _execute_bash(repo_ctx, "which ld")
    lld = _execute_bash(repo_ctx, "which lld")
    if ld:
        return ld
    elif lld:
        return lld
    else:
        fail("No linker found")

def _find_compiler(repo_ctx):
    gcc = _execute_bash(repo_ctx, "which g++")
    clang = _execute_bash(repo_ctx, "which clang++")
    if gcc:
        return gcc
    elif clang:
        return clang
    else:
        fail("No compiler found")

def _find_lib_path(repo_ctx, lib_name, archive_names, lib_path_hints):
    override_paths = _get_list_from_env_var(
        repo_ctx,
        BAZEL_LIB_OVERRIDE_PATHS_ENV_VAR,
        lib_name,
    )
    additional_paths = _get_list_from_env_var(
        repo_ctx,
        BAZEL_LIB_ADDITIONAL_PATHS_ENV_VAR,
        lib_name,
    )

    # Directories will be searched in order
    path_flags = _make_flags(
        override_paths + lib_path_hints + additional_paths,
        "-L",
    )
    linker = _find_linker(repo_ctx)
    for archive_name in archive_names:
        cmd = """
              {} -verbose -l:{} {} 2>/dev/null | \\
              grep succeeded | \\
              head -1 | \\
              sed -e 's/^\\s*attempt to open //' -e 's/ succeeded\\s*$//'
              """.format(
            linker,
            archive_name,
            path_flags,
        )
        path = _execute_bash(repo_ctx, cmd)
        if path:
            return (archive_name, path)
    return ("", "")

def _find_header_path(repo_ctx, lib_name, header_name, includes):
    override_paths = _get_list_from_env_var(
        repo_ctx,
        BAZEL_INCLUDE_OVERRIDE_PATHS_ENV_VAR,
        lib_name,
    )
    additional_paths = _get_list_from_env_var(
        repo_ctx,
        BAZEL_INCLUDE_ADDITIONAL_PATHS_ENV_VAR,
        lib_name,
    )

    # See https://gcc.gnu.org/onlinedocs/gcc/Directory-Options.html
    override_include_flags = _make_flags(override_paths, "-I")
    standard_include_flags = _make_flags(includes, "-isystem")
    additional_include_flags = _make_flags(additional_paths, "-idirafter")

    compiler = _find_compiler(repo_ctx)

    # Taken from https://stackoverflow.com/questions/63052707/which-header-exactly-will-c-preprocessor-include/63052918#63052918
    cmd = """
          f=\"{}\"; \\
          echo | \\
          {} -E {} {} {} -Wp,-v - 2>&1 | \\
          sed '\\~^ /~!d; s/ //' | \\
          while IFS= read -r path; \\
              do if [[ -e \"$path/$f\" ]]; \\
                  then echo \"$path/$f\";  \\
                  break; \\
              fi; \\
          done
          """.format(
        header_name,
        compiler,
        override_include_flags,
        standard_include_flags,
        additional_include_flags,
    )
    return _execute_bash(repo_ctx, cmd)

def system_library_impl(repo_ctx):
    repo_name = repo_ctx.attr.name
    includes = repo_ctx.attr.includes
    hdrs = repo_ctx.attr.hdrs
    optional_hdrs = repo_ctx.attr.optional_hdrs
    deps = repo_ctx.attr.deps
    lib_path_hints = repo_ctx.attr.lib_path_hints
    static_lib_names = repo_ctx.attr.static_lib_names
    shared_lib_names = repo_ctx.attr.shared_lib_names

    static_lib_name, static_lib_path = \
        _find_lib_path(repo_ctx, repo_name, static_lib_names, lib_path_hints)
    shared_lib_name, shared_lib_path = \
        _find_lib_path(repo_ctx, repo_name, shared_lib_names, lib_path_hints)

    if not static_lib_path and not shared_lib_path:
        fail("Library {} could not be found".format(repo_name))

    hdr_names = []
    hdr_paths = []
    for hdr in hdrs:
        hdr_path = _find_header_path(repo_ctx, repo_name, hdr, includes)
        if hdr_path:
            repo_ctx.symlink(hdr_path, hdr)
            hdr_names.append(hdr)
            hdr_paths.append(hdr_path)
        else:
            fail("Could not find required header {}".format(hdr))

    for hdr in optional_hdrs:
        hdr_path = _find_header_path(repo_ctx, repo_name, hdr, includes)
        if hdr_path:
            repo_ctx.symlink(hdr_path, hdr)
            hdr_names.append(hdr)
            hdr_paths.append(hdr_path)

    hdrs_param = "hdrs = {},".format(str(hdr_names))

    # This is needed for the case when quote-includes and system-includes
    # alternate in the include chain, i.e.
    # #include <SDL2/SDL.h> -> #include "SDL_main.h"
    # -> #include <SDL2/_real_SDL_config.h> -> #include "SDL_platform.h"
    # The problem is that the quote-includes are assumed to be
    # in the same directory as the header they are included from -
    # they have no subdir prefix ("SDL2/") in their paths
    include_subdirs = {}
    for hdr in hdr_names:
        path_segments = hdr.split("/")
        path_segments.pop()
        current_path_segments = ["external", repo_name]
        for segment in path_segments:
            current_path_segments.append(segment)
            current_path = "/".join(current_path_segments)
            include_subdirs.update({current_path: None})

    includes_param = "includes = {},".format(str(include_subdirs.keys()))

    deps_names = []
    for dep in deps:
        dep_name = repr("@" + dep)
        deps_names.append(dep_name)
    deps_param = "deps = [{}],".format(",".join(deps_names))

    link_hdrs_command = "mkdir -p $(RULEDIR)/remote \n"
    remote_hdrs = []
    for path, hdr in zip(hdr_paths, hdr_names):
        remote_hdr = "remote/" + hdr
        remote_hdrs.append(remote_hdr)
        link_hdrs_command += "cp {path} $(RULEDIR)/{hdr}\n ".format(
            path = path,
            hdr = remote_hdr,
        )

    link_remote_static_lib_genrule = ""
    link_remote_shared_lib_genrule = ""
    remote_static_library_param = ""
    remote_shared_library_param = ""
    static_library_param = ""
    shared_library_param = ""

    if static_lib_path:
        repo_ctx.symlink(static_lib_path, static_lib_name)
        static_library_param = "static_library = \"{}\",".format(
            static_lib_name,
        )
        remote_static_library = "remote/" + static_lib_name
        link_library_command = \
            "mkdir -p $(RULEDIR)/remote && cp {path} $(RULEDIR)/{lib}".format(
                path = static_lib_path,
                lib = remote_static_library,
            )
        remote_static_library_param = \
            "static_library = \"remote_link_static_library\","
        link_remote_static_lib_genrule = \
            """
genrule(
     name = "remote_link_static_library",
     outs = ["{remote_static_library}"],
     cmd = {link_library_command}
)
""".format(
                link_library_command = repr(link_library_command),
                remote_static_library = remote_static_library,
            )

    if shared_lib_path:
        repo_ctx.symlink(shared_lib_path, shared_lib_name)
        shared_library_param = \
            "shared_library = \"{}\",".format(shared_lib_name)
        remote_shared_library = "remote/" + shared_lib_name
        link_library_command = \
            "mkdir -p $(RULEDIR)/remote && cp {path} $(RULEDIR)/{lib}".format(
                path = shared_lib_path,
                lib = remote_shared_library,
            )
        remote_shared_library_param = \
            "shared_library = \"remote_link_shared_library\","
        link_remote_shared_lib_genrule = \
            """
genrule(
        name = "remote_link_shared_library",
        outs = ["{remote_shared_library}"],
        cmd = {link_library_command}
)
""".format(
                link_library_command = repr(link_library_command),
                remote_shared_library = remote_shared_library,
            )

    repo_ctx.file(
        "BUILD",
        executable = False,
        content =
            """
load("@bazel_tools//tools/build_defs/cc:cc_import.bzl", "cc_import")
cc_import(
    name = "local_includes",
    {static_library}
    {shared_library}
    {hdrs}
    {deps}
    {includes}
)

genrule(
    name = "remote_link_headers",
    outs = {remote_hdrs},
    cmd = {link_hdrs_command}
)

{link_remote_static_lib_genrule}

{link_remote_shared_lib_genrule}

cc_import(
    name = "remote_includes",
    hdrs = [":remote_link_headers"],
    {remote_static_library}
    {remote_shared_library}
    {deps}
    {includes}
)

alias(
    name = "{name}",
    actual = select({{
        "@bazel_tools//src/conditions:remote": "remote_includes",
        "//conditions:default": "local_includes",
    }}),
    visibility = ["//visibility:public"],
)
""".format(
                static_library = static_library_param,
                shared_library = shared_library_param,
                hdrs = hdrs_param,
                deps = deps_param,
                hdr_names = str(hdr_names),
                link_hdrs_command = repr(link_hdrs_command),
                name = repo_name,
                includes = includes_param,
                remote_hdrs = remote_hdrs,
                link_remote_static_lib_genrule = link_remote_static_lib_genrule,
                link_remote_shared_lib_genrule = link_remote_shared_lib_genrule,
                remote_static_library = remote_static_library_param,
                remote_shared_library = remote_shared_library_param,
            ),
    )

system_library = repository_rule(
    implementation = system_library_impl,
    local = True,
    remotable = True,
    environ = [
        BAZEL_LIB_ADDITIONAL_PATHS_ENV_VAR,
        BAZEL_LIB_OVERRIDE_PATHS_ENV_VAR,
        BAZEL_INCLUDE_ADDITIONAL_PATHS_ENV_VAR,
        BAZEL_INCLUDE_OVERRIDE_PATHS_ENV_VAR,
    ],
    attrs = {
        "static_lib_names": attr.string_list(),
        "shared_lib_names": attr.string_list(),
        "lib_path_hints": attr.string_list(),
        "includes": attr.string_list(),
        "hdrs": attr.string_list(mandatory = True, allow_empty = False),
        "optional_hdrs": attr.string_list(),
        "deps": attr.string_list(),
    },
)
