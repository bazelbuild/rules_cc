#!/bin/bash

# ==============================================================================
# 动态查找 GCC 并实时修复 Sysroot 路径问题的 Wrapper
# Wrapper to dynamically find GCC and fix Sysroot path issues on the fly.
# ==============================================================================

# 1. 获取当前工作目录 (Bazel execroot)
#    Get current working directory (Bazel execroot).
REPO_ROOT=$(pwd)

# 2. 动态查找 GCC 编译器
#    Dynamically locate the GCC compiler.
#    We limit the search to the 'external/' directory to avoid scanning the whole source tree.
#    我们限制查找范围在 external/ 目录下，避免扫描整个源码树。
GCC_NAME="x86_64-linux-g++.br_real"
LD_NAME="x86_64-linux-ld"

REL_GCC_PATH=$(find -L external -name "${GCC_NAME}" -prune -type f -print -quit)

if [[ -z "${REL_GCC_PATH}" ]]; then
    echo "ERROR: [ld.sh] Could not find ${GCC_NAME} in external/" >&2
    exit 1
fi

REAL_GCC="${REPO_ROOT}/${REL_GCC_PATH}"
TOOL_DIR=$(dirname "${REAL_GCC}")
REAL_LD="${TOOL_DIR}/${LD_NAME}"

# 检查 LD 是否存在
# Check if the linker (LD) exists.
if [[ ! -f "${REAL_LD}" ]]; then
    echo "ERROR: [ld.sh] Found GCC at ${REAL_GCC} but LD not found at ${REAL_LD}" >&2
    exit 1
fi

# 3. 创建临时工作目录
#    Create temporary working directories.
TEMP_DIR=$(mktemp -d)
TEMP_BIN_DIR="${TEMP_DIR}/bin"
mkdir -p "${TEMP_BIN_DIR}"

# 建立 'ld' 软链接欺骗 GCC
# Create a symlink named 'ld' to trick GCC.
# GCC calls 'ld' based on the directory specified by -B.
ln -sf "${REAL_LD}" "${TEMP_BIN_DIR}/ld"

# ==============================================================================
# 修复逻辑：处理 libm.so / libc.so 中的绝对路径
# Fix Logic: Handle absolute paths in libm.so / libc.so.
# ==============================================================================

# 4.1 解析参数找到 sysroot 路径
#     Parse arguments to find the sysroot path.
SYSROOT_PATH=""
for arg in "$@"; do
    if [[ "$arg" == --sysroot=* ]]; then
        SYSROOT_PATH="${arg#*=}"
        break
    fi
done

# 存放修复后库文件的目录
# Directory to store fixed library files.
FIXED_LIB_DIR="${TEMP_DIR}/fixed_lib"
mkdir -p "${FIXED_LIB_DIR}"

# 4.2 定义修复函数
#     Define the fix function.
fix_linker_script() {
    local src_file="$1"
    
    # 只有文件存在时才处理
    # Process only if the file exists.
    if [[ -f "${src_file}" ]]; then
        local file_name=$(basename "$src_file")
        local dst_file="${FIXED_LIB_DIR}/${file_name}"
        
        # 复制文件到临时目录 (避免修改只读的源文件)
        # Copy file to temp dir (avoid modifying read-only source files).
        cp "${src_file}" "${dst_file}"
        chmod +w "${dst_file}"
        
        # === 关键修正：按顺序替换路径 ===
        # === Critical Fix: Replace paths in specific order ===
        
        # 1. 先替换最长的路径前缀 (/usr/lib64/ 和 /usr/lib/)
        #    这样可以避免把 /usr/lib/xxx 错误地变成 /usrlib/xxx 或 /usrxxx
        # 1. Replace longest path prefixes first (/usr/lib64/ and /usr/lib/).
        #    This prevents corrupting paths like /usr/lib/xxx into /usrlib/xxx.
        sed -i 's|/usr/lib64/||g' "${dst_file}"
        sed -i 's|/usr/lib/||g' "${dst_file}"
        
        # 2. 再替换短的路径前缀 (/lib64/ 和 /lib/)
        # 2. Then replace shorter path prefixes (/lib64/ and /lib/).
        sed -i 's|/lib64/||g' "${dst_file}"
        sed -i 's|/lib/||g' "${dst_file}"
    fi
}

if [[ -n "${SYSROOT_PATH}" ]]; then
    # 尝试修复 libm.so (数学库)
    # Attempt to fix libm.so (Math library).
    fix_linker_script "${SYSROOT_PATH}/usr/lib/libm.so"
    fix_linker_script "${SYSROOT_PATH}/lib/libm.so"
    fix_linker_script "${SYSROOT_PATH}/usr/lib64/libm.so"

    # 尝试修复 libc.so (C 标准库)
    # Attempt to fix libc.so (C Standard library).
    fix_linker_script "${SYSROOT_PATH}/usr/lib/libc.so"
    fix_linker_script "${SYSROOT_PATH}/lib/libc.so"
    fix_linker_script "${SYSROOT_PATH}/usr/lib64/libc.so"
fi

# ==============================================================================
# 5. 调用 GCC 进行链接
#    Invoke GCC to perform linking.
# ==============================================================================

EXTRA_ARGS=()

# 如果有修复后的库，将该目录加入搜索路径 (-L)
# If fixed libraries exist, add their directory to the search path (-L).
if [[ -d "${FIXED_LIB_DIR}" ]]; then
    EXTRA_ARGS+=("-L${FIXED_LIB_DIR}")
fi

# -no-canonical-prefixes: 防止 GCC 将路径展开为绝对路径
# -no-canonical-prefixes: Prevents GCC from resolving paths to absolute paths.
# -B: 指向包含 'ld' 软链接的目录 / Points to the dir containing the 'ld' symlink.
exec "${REAL_GCC}" \
    -no-canonical-prefixes \
    -B "${TEMP_BIN_DIR}" \
    "${EXTRA_ARGS[@]}" \
    "$@"