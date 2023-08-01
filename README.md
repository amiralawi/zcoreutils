# zcoreutils
Coreutils equivalents written in zig

# Design Philosophy
zcoreutils is a set of binaries intended to replace common utilities used in unix-like environments.  This project was partially borne out of my desire to learn zig and partially as a result of my own personal annoyance at large binary sizes for common "simple" utilities for embedded applications.

In order of (approximate) precedence:

1. Make behavior as close as possible to gnu coreutils equivalents
2. Functional correctness
3. Minimize memory consumption
4. Minimize code size

# Completed / near-complete utilities
* zecho - needs escape character support

# In progress utilities
* zls
 
# Planned utilities
In order of (approximate) precedence:

1. ztouch
2. zmkdir
3. zcp
4. zmv
