load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("//:local_bazel.bzl", "local_bazel_import")

SHORT_VERSION_MAPPING = {
    "bazel_7": "7.7.1",
    "bazel_8": "8.7.0",
    "bazel_9": "9.1.0",
}

SHA_MATRIX = {
    "7.7.1": {
        "linux_x86_64": "115a1b62be95f29e5821d4dddffba1b058905a48019b499919c285e7f708d5e2",
        "linux_arm64":  "71df04ec724f1b577f1f47ec9a6b81d13f39683f6c3215cacf45fdaf40b2c5c1",
        "darwin_x86_64": "8582aea5ee2d8d0448bbda10fd7034734db1a21cbe4ea351a10012b969aa5d31",
        "darwin_arm64":  "fe8a1ee9064e94afae075c0dd4efb453db9c1373b9df12fecbff8479d408eb08",
        "windows_x86_64": "6d9fb21e806cf4f4e61bfa2bc865df4900ffdc1e9ea90ca1016ba70367ef0de4",
    },
    "8.7.0": {
        "linux_x86_64": "d7606e679b78067c811096fb3d6cf135225b528835ca396e3a4dddf957859544",
        "linux_arm64":  "bfe9558bd8a2ecfe4841ec46c0dbccb4b469fe22d81f2f859de0de222b3e7ce3",
        "darwin_x86_64": "76f3eb05782098e9f9ddd8247ec969b085195a3ae2978c81721a2235052ccf26",
        "darwin_arm64":  "575f20fb23955e02f73519befd180df635b4ed0960c60f0e70fcc8d74014a713",
        "windows_x86_64": "29f1796f57379933340afa135f02703ffa21dd30135754bea695f8fd15103420",
    },
    "9.1.0": {
        "linux_x86_64": "a667454f3f4f8878df8199136b82c199f6ada8477b337fae3b1ef854f01e4e2f",
        "linux_arm64":  "ba933bfc943e4c44f0743a5823aa2312a34b39628532add5dd037e08d8ec27a4",
        "darwin_x86_64": "666c6c79eda285cada5f5c39c891c6dd7ee0971b20bff365ea87a4b897271433",
        "darwin_arm64":  "084a1784fa8f0dcae77fb4e88faa15048d8149a36c947ce198508bffb060e1bb",
        "windows_x86_64": "b457dccd36a9bb9be01326cc1d069a201bb50b4b94562a652afb6f43c5148d42",
    },
}

def _remote_bazel_extension_impl(module_ctx):
    os_name = module_ctx.os.name.lower()
    os_key = "linux"
    exe_extension = ""
    if "windows" in os_name:
        os_key = "windows"
        exe_extension = ".exe"
    elif "mac" in os_name or "darwin" in os_name:
        os_key = "darwin"

    cpu_arch = module_ctx.os.arch.lower()
    if "x86_64" in cpu_arch or "amd64" in cpu_arch:
        arch_key = "x86_64"
    elif "arm64" in cpu_arch:
        arch_key = "arm64"
    else:
        fail("Unsupported architecture '{}'.".format(cpu_arch))

    platform_key = "{}_{}".format(os_key, arch_key)

    requested_versions = {}
    for mod in module_ctx.modules:
        for tag in mod.tags.download:
            requested_versions[tag.bazel_version] = True

    for bazel_version in requested_versions:
        if bazel_version not in SHORT_VERSION_MAPPING:
            fail("Unrecognised version '%s'" % bazel_version)
        version = SHORT_VERSION_MAPPING[bazel_version]
        filename = "bazel-%s-%s-%s%s" % (version, os_key, arch_key, exe_extension)
        url = "https://github.com/bazelbuild/bazel/releases/download/%s/%s" % (version, filename)

        http_file(
            name = bazel_version,
            downloaded_file_path = "bazel" + exe_extension,
            executable = True,
            url = url,
            sha256 = SHA_MATRIX[version][platform_key],
        )


def _local_bazel_extension_impl(module_ctx):
    local_bazel_import(name = "local_bazel")

download_tag = tag_class(attrs = {"bazel_version": attr.string(mandatory = True)})

remote_bazel_extension = module_extension(
    implementation = _remote_bazel_extension_impl,
    tag_classes = {"download": download_tag},
)

local_bazel_extension = module_extension(
    implementation = _local_bazel_extension_impl,
)
