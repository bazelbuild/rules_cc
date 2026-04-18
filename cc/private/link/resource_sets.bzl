# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Pre-built resource_set callbacks for link actions.

Bazel's actions.run(resource_set=...) requires a top-level function (no closures).
This module provides a lookup table of pre-built callbacks for common memory/cpu
combinations. User-specified values are rounded up to the nearest supported level.
"""

_MEMORY_LEVELS = [256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536]
_CPU_LEVELS = [1, 2, 4, 8, 16]

# --- Generated top-level resource_set functions ---
# Each function has the signature (os, inputs) -> dict as required by actions.run().

def _rs_256_1(_os, _inputs):
    return {"memory": 256, "cpu": 1}

def _rs_256_2(_os, _inputs):
    return {"memory": 256, "cpu": 2}

def _rs_256_4(_os, _inputs):
    return {"memory": 256, "cpu": 4}

def _rs_256_8(_os, _inputs):
    return {"memory": 256, "cpu": 8}

def _rs_256_16(_os, _inputs):
    return {"memory": 256, "cpu": 16}

def _rs_512_1(_os, _inputs):
    return {"memory": 512, "cpu": 1}

def _rs_512_2(_os, _inputs):
    return {"memory": 512, "cpu": 2}

def _rs_512_4(_os, _inputs):
    return {"memory": 512, "cpu": 4}

def _rs_512_8(_os, _inputs):
    return {"memory": 512, "cpu": 8}

def _rs_512_16(_os, _inputs):
    return {"memory": 512, "cpu": 16}

def _rs_1024_1(_os, _inputs):
    return {"memory": 1024, "cpu": 1}

def _rs_1024_2(_os, _inputs):
    return {"memory": 1024, "cpu": 2}

def _rs_1024_4(_os, _inputs):
    return {"memory": 1024, "cpu": 4}

def _rs_1024_8(_os, _inputs):
    return {"memory": 1024, "cpu": 8}

def _rs_1024_16(_os, _inputs):
    return {"memory": 1024, "cpu": 16}

def _rs_2048_1(_os, _inputs):
    return {"memory": 2048, "cpu": 1}

def _rs_2048_2(_os, _inputs):
    return {"memory": 2048, "cpu": 2}

def _rs_2048_4(_os, _inputs):
    return {"memory": 2048, "cpu": 4}

def _rs_2048_8(_os, _inputs):
    return {"memory": 2048, "cpu": 8}

def _rs_2048_16(_os, _inputs):
    return {"memory": 2048, "cpu": 16}

def _rs_4096_1(_os, _inputs):
    return {"memory": 4096, "cpu": 1}

def _rs_4096_2(_os, _inputs):
    return {"memory": 4096, "cpu": 2}

def _rs_4096_4(_os, _inputs):
    return {"memory": 4096, "cpu": 4}

def _rs_4096_8(_os, _inputs):
    return {"memory": 4096, "cpu": 8}

def _rs_4096_16(_os, _inputs):
    return {"memory": 4096, "cpu": 16}

def _rs_8192_1(_os, _inputs):
    return {"memory": 8192, "cpu": 1}

def _rs_8192_2(_os, _inputs):
    return {"memory": 8192, "cpu": 2}

def _rs_8192_4(_os, _inputs):
    return {"memory": 8192, "cpu": 4}

def _rs_8192_8(_os, _inputs):
    return {"memory": 8192, "cpu": 8}

def _rs_8192_16(_os, _inputs):
    return {"memory": 8192, "cpu": 16}

def _rs_16384_1(_os, _inputs):
    return {"memory": 16384, "cpu": 1}

def _rs_16384_2(_os, _inputs):
    return {"memory": 16384, "cpu": 2}

def _rs_16384_4(_os, _inputs):
    return {"memory": 16384, "cpu": 4}

def _rs_16384_8(_os, _inputs):
    return {"memory": 16384, "cpu": 8}

def _rs_16384_16(_os, _inputs):
    return {"memory": 16384, "cpu": 16}

def _rs_32768_1(_os, _inputs):
    return {"memory": 32768, "cpu": 1}

def _rs_32768_2(_os, _inputs):
    return {"memory": 32768, "cpu": 2}

def _rs_32768_4(_os, _inputs):
    return {"memory": 32768, "cpu": 4}

def _rs_32768_8(_os, _inputs):
    return {"memory": 32768, "cpu": 8}

def _rs_32768_16(_os, _inputs):
    return {"memory": 32768, "cpu": 16}

def _rs_65536_1(_os, _inputs):
    return {"memory": 65536, "cpu": 1}

def _rs_65536_2(_os, _inputs):
    return {"memory": 65536, "cpu": 2}

def _rs_65536_4(_os, _inputs):
    return {"memory": 65536, "cpu": 4}

def _rs_65536_8(_os, _inputs):
    return {"memory": 65536, "cpu": 8}

def _rs_65536_16(_os, _inputs):
    return {"memory": 65536, "cpu": 16}

# --- Lookup table ---

_RESOURCE_SETS = {
    256: {1: _rs_256_1, 2: _rs_256_2, 4: _rs_256_4, 8: _rs_256_8, 16: _rs_256_16},
    512: {1: _rs_512_1, 2: _rs_512_2, 4: _rs_512_4, 8: _rs_512_8, 16: _rs_512_16},
    1024: {1: _rs_1024_1, 2: _rs_1024_2, 4: _rs_1024_4, 8: _rs_1024_8, 16: _rs_1024_16},
    2048: {1: _rs_2048_1, 2: _rs_2048_2, 4: _rs_2048_4, 8: _rs_2048_8, 16: _rs_2048_16},
    4096: {1: _rs_4096_1, 2: _rs_4096_2, 4: _rs_4096_4, 8: _rs_4096_8, 16: _rs_4096_16},
    8192: {1: _rs_8192_1, 2: _rs_8192_2, 4: _rs_8192_4, 8: _rs_8192_8, 16: _rs_8192_16},
    16384: {1: _rs_16384_1, 2: _rs_16384_2, 4: _rs_16384_4, 8: _rs_16384_8, 16: _rs_16384_16},
    32768: {1: _rs_32768_1, 2: _rs_32768_2, 4: _rs_32768_4, 8: _rs_32768_8, 16: _rs_32768_16},
    65536: {1: _rs_65536_1, 2: _rs_65536_2, 4: _rs_65536_4, 8: _rs_65536_8, 16: _rs_65536_16},
}

def _round_up(value, levels):
    """Rounds value up to the nearest level. Clamps to the max level."""
    for level in levels:
        if level >= value:
            return level
    return levels[-1]

_VALID_RESOURCE_SET_KEYS = ["memory", "cpu"]

def make_link_resource_set(resource_set_dict):
    """Returns a resource_set callback for actions.run(), or None for defaults.

    Values are rounded up to the nearest supported level (memory: powers of 2 from
    256 to 65536 MB; cpu: 1, 2, 4, 8, 16).

    Args:
        resource_set_dict: dict[str, str] from the link_resource_set attr.
            Keys: "memory" (MB), "cpu". Empty dict means use default heuristic.

    Returns:
        A callable (os, inputs) -> dict, or None.
    """
    if not resource_set_dict:
        return None
    for key in resource_set_dict:
        if key not in _VALID_RESOURCE_SET_KEYS:
            fail("Invalid link_resource_set key '{}'. Valid keys: {}".format(key, _VALID_RESOURCE_SET_KEYS))
    mem = int(resource_set_dict["memory"]) if "memory" in resource_set_dict else 250
    cpu = int(resource_set_dict.get("cpu", "1"))
    if mem <= 0:
        fail("link_resource_set memory must be positive, got {}".format(mem))
    if cpu <= 0:
        fail("link_resource_set cpu must be positive, got {}".format(cpu))
    mem = _round_up(mem, _MEMORY_LEVELS)
    cpu = _round_up(cpu, _CPU_LEVELS)
    return _RESOURCE_SETS[mem][cpu]
