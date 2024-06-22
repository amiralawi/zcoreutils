# zcoreutils
Coreutils equivalents written in zig

# Installation
Run `zig build` with appropriate options (such as `zig build -Doptimize=ReleaseSmall`) to build all utilities.  Binaries are placed in the the `zig-out/bin` folder.

# Design Philosophy
zcoreutils is a set of binaries intended to replace common utilities used in unix-like environments.  This project was partially borne out of my desire to learn zig and partially as a result of my own personal annoyance at large binary sizes for common "simple" utilities, particularly for embedded applications.

In order of (approximate) precedence:

1. Make behavior as close as possible to gnu coreutils equivalents unless it is obviously stupid
2. Functional correctness
3. Minimize memory consumption
4. Minimize code size

# Utility Status
| Utility   | Status      | zargh?   | Notes
| --------- | ----------- |----------|--------
| zbasename | 100%        | yes      | 
| zfalse    | 100%        | yes      | 
| ztrue     | 100%        | yes      | 
| zyes      | 100%        | yes      | 
| zsleep    | 99%         | yes      | need to check error handling, return codes
| zcksum    | 99%         |          | need to check error handling, return codes
| zrmdir    | 99%         |          | need to check error handling, return codes
| zecho     | 95%         | yes      | does not currently support \e, \E, \u, \U
| zrm       | 90%         | yes      | Missing -I resurive prompting. Does not implement: --no-preserve-root, --preserve-root=all, --one-file-system
| zhead     | 85%         |          | does not support: long --bytes and --lines options, negative bytecount/linecount
| zwc       | 80%         |          | probably implements bytes-vs-chars incorrectly, does not implement --files0-from=F
| ztouch    | 75%         |          | does not implement timestamp/datestamp options, no-dereference, reference
| zmkdir    | 50%         |          | does not implement context/mode
| ztee      | 50%         |          | does not implement interrupts
| zseq      | 50%         |          | does not implement argument behaviors, negative inputs, NaN
| ztail     | usable      |          | demonstrator only, prints 10 lines, no CLI option support yet
| zcat      | usable      |          | demonstrator only, prints full file, no CLI option support yet
| hostname  | 5%          |          | doesn't take arguments
| zls       | in-progress |          | demonstrator only, missing lots of features
| zcp       | preliminary |          | demonstrator only
| zmv       | preliminary |          | demonstrator only
| zcomm     | preliminary |          | skeleton
| hostid    | preliminary |          | skeleton
| base64    | preliminary |          | skeleton