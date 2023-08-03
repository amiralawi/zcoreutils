# zcoreutils
Coreutils equivalents written in zig

# Design Philosophy
zcoreutils is a set of binaries intended to replace common utilities used in unix-like environments.  This project was partially borne out of my desire to learn zig and partially as a result of my own personal annoyance at large binary sizes for common "simple" utilities, particularly for embedded applications.

In order of (approximate) precedence:

1. Make behavior as close as possible to gnu coreutils equivalents
2. Functional correctness
3. Minimize memory consumption
4. Minimize code size

# Utility Status
| Utility | Status | Notes
| ------- | ----------- |----
| zecho   | mostly done | does not currently support \e, \E, \u, \U
| zhead   | usable      | prints 10 lines, no CLI option support yet
| ztail   | usable      | prints 10 lines, no CLI option support yet
| zls     | in-progress | missing lots of features
| zmkdir  | not started |
| zcp     | not started | 
| zmv     | not started |
