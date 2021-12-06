#ifndef _CLANG_FORMAT_UTILS_H_INCLUDE_
#define _CLANG_FORMAT_UTILS_H_INCLUDE_

#include <string>
#include <vector>

#include WORKSPACE_HEADER

namespace clang_format_utils {

/**
 * @brief Get the working path object
 *
 * @return std::string
 *  The current working directory.
 */
std::string get_working_path();

/**
 * @brief Changes the current working directory to the specified path.
 *
 * @param path
 *  The path to change the workign directory to.
 * @return int
 *  The exit code of the command.
 */
int set_current_dir(const std::string& path);

/**
 * @brief Copy a file to a new destination.
 *
 * If the parent directory of `dest` does not exist, it will be made.
 *
 * @param src
 *  The file to copy.
 * @param dest
 *  The location where to copy the file to.
 * @return int
 *  The exit code of the copy command.
 */
int copy_file(const std::string& src, const std::string& dest);

}  // namespace clang_format_utils

#endif
