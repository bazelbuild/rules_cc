; Copyright 2026 The Bazel Authors. All rights reserved.
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;    http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

; Default toolchain defines must still reach MASM after compiler-only flags
; are removed from the assemble action.
IFNDEF NOMINMAX
    .ERR <NOMINMAX missing>
ENDIF
IFNDEF _CRT_SECURE_NO_DEPRECATE
    .ERR <_CRT_SECURE_NO_DEPRECATE missing>
ENDIF
IFNDEF _CRT_SECURE_NO_WARNINGS
    .ERR <_CRT_SECURE_NO_WARNINGS missing>
ENDIF
IFNDEF _WIN32_WINNT
    .ERR <_WIN32_WINNT missing>
ENDIF

; A rule-level define must be available as well as the toolchain defaults.
IFNDEF MASM_TEST_VALUE
    .ERR <MASM_TEST_VALUE missing>
ENDIF

.code
PUBLIC masm_return_value
masm_return_value PROC
    mov eax, MASM_TEST_VALUE
    ret
masm_return_value ENDP
END
