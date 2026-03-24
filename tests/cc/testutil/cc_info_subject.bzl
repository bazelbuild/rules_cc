"""A custom @rules_testing subject for the CcInfo provider"""

load("@rules_testing//lib:truth.bzl", "subjects")
load("//cc/common:cc_info.bzl", "CcInfo")
load(":testutil.bzl", "testutil")

def _new_cc_info_subject(cc_info, meta):
    self = struct(
        actual = cc_info,
        meta = meta,
    )
    public = struct(
        compilation_context = lambda: _new_cc_compilation_context_subject(
            self.actual.compilation_context,
            self.meta.derive("compilation_context"),
        ),
        linking_context = lambda: _new_cc_info_linking_context_subject(self.actual, self.meta),
        native_libraries = lambda: subjects.collection(
            testutil.cc_info_transitive_native_libraries(self.actual),
            self.meta.derive("transitive_native_libraries()"),
        ),
    )
    return public

def _new_cc_info_subject_from_target(env, target):
    env.expect.that_target(target).has_provider(CcInfo)
    return _new_cc_info_subject(target[CcInfo], env.expect.meta)

def _new_cc_compilation_context_subject(cc_compilation_context, meta):
    self = struct(
        actual = cc_compilation_context,
        meta = meta,
    )
    public = struct(
        include_dirs = lambda: subjects.collection(
            self.actual.includes.to_list(),
            self.meta.derive("include_dirs"),
        ),
        system_include_dirs = lambda: subjects.collection(
            self.actual.system_includes.to_list(),
            self.meta.derive("system_include_dirs"),
        ),
        quote_include_dirs = lambda: subjects.collection(
            self.actual.quote_includes.to_list(),
            self.meta.derive("quote_include_dirs"),
        ),
        external_include_dirs = lambda: subjects.collection(
            self.actual.external_includes.to_list(),
            self.meta.derive("external_include_dirs"),
        ),
    )
    return public

def _new_cc_info_linking_context_subject(cc_info, meta):
    self = struct(
        actual = cc_info.linking_context,
        meta = meta.derive("linking_context"),
    )
    public = struct(
        equals = lambda other: _cc_info_linking_context_equals(self.actual, other, self.meta),
        library_files = lambda: _new_library_files_subject(self.actual, self.meta),
        static_library_files = lambda: _new_static_library_files_subject(self.actual, self.meta),
    )
    return public

def _new_library_files_subject(linking_context, meta):
    libs = []
    for input in linking_context.linker_inputs.to_list():
        for lib in input.libraries:
            if lib.pic_static_library:
                libs.append(lib.pic_static_library)
            elif lib.static_library:
                libs.append(lib.static_library)
            elif lib.interface_library:
                libs.append(lib.interface_library)
            else:
                libs.append(lib.dynamic_library)

    return subjects.depset_file(
        depset(libs),
        meta = meta.derive("library_files"),
    )

def _new_static_library_files_subject(linking_context, meta):
    static_libraries = []
    for input in linking_context.linker_inputs.to_list():
        for lib in input.libraries:
            if lib.static_library:
                static_libraries.append(lib.static_library)
    return subjects.depset_file(
        depset(static_libraries),
        meta = meta.derive("static_library_files"),
    )

def _cc_info_linking_context_equals(actual, expected, meta):
    if actual == expected:
        return
    meta.add_failure(
        "expected: {}".format(expected),
        "actual: {}".format(actual),
    )

def _new_cc_info_libraries_to_link_subject(libraries_to_link, meta):
    if hasattr(libraries_to_link, "to_list"):
        libraries_to_link = libraries_to_link.to_list()
    self = struct(
        actual = libraries_to_link,
        meta = meta,
    )
    public = struct(
        static_libraries = lambda: _new_library_to_link_static_libraries_subject(self.actual, self.meta),
        singleton = lambda: _new_library_to_link_subject(_get_singleton(self.actual), self.meta.derive("[0]")),
    )
    return public

def _new_library_to_link_subject(library_to_link, meta):
    public = struct(
        dynamic_library = lambda: subjects.file(library_to_link.dynamic_library, meta.derive("dynamic_library")),
    )
    return public

def _new_library_to_link_static_libraries_subject(libraries_to_link, meta):
    self = subjects.collection(
        [testutil.cc_library_to_link_static_library(lib) for lib in libraries_to_link],
        meta = meta.derive("static_library()"),
    ).transform(desc = "basename", map_each = lambda file: file.basename)
    public = struct(
        contains_exactly = lambda expected: self.contains_exactly([meta.format_str(e) for e in expected]),
        contains_exactly_predicates = lambda expected: self.contains_exactly_predicates(expected),
    )
    return public

def _get_singleton(seq):
    if len(seq) != 1:
        fail("expected singleton, got:", seq)
    return seq[0]

cc_info_subject = struct(
    from_target = _new_cc_info_subject_from_target,
    libraries_to_link = _new_cc_info_libraries_to_link_subject,
    new_from_cc_info = lambda cc_info, meta: _new_cc_info_subject(cc_info, meta),
    new_from_java_info = lambda java_info, meta: _new_cc_info_subject(java_info.cc_link_params_info, meta.derive("cc_link_params_info")),
)
