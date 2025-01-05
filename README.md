# Jai Hello World example for Raspberry Pi

This repo serves as an example Jai project for the Raspberry Pi (64-bit). The LLVM backend is used to target the machine, and a few hacks to Jai's built-in modules are needed to get basic support working somewhat decently since ARM64 is not currently a first-class target.

## Setup

I recommend storing Jon's Jai beta releases in a Git repo. You can then make a new branch just for working with the Raspberry Pi hacks you'll need to install. From there, in the root of the Jai release folder, do:

```sh
git apply --ignore-whitespace /path/to/jai-module-hacks.patch
```

Next, go grab a cross-compiling GCC for the Raspberry Pi and add it to your `PATH`. [This page](https://github.com/abhiTronix/raspberry-pi-cross-compilers/wiki/64-Bit-Cross-Compiler:-Installation-Instructions) thankfully has some pre-built binaries for an x64 Linux host. At the time of writing, I choose download for Debian Bookworm and GCC 14.2.0.

## Building

It should be as simple as:

```sh
jai-linux first.jai
```

You can add specify whether to built for the host or target machine with `-host` and `-target` respectively:

```sh
jai-linux first.jai - -host
jai-linux first.jai - -target
```

## Running



## Thanks to...

* @ctp and @ctpeepee in the Discord server for helping with the module hacks
* [tsoding](https://github.com/tsoding) for the metaprogram scripts that let you report and strip out all uses of inline assembly (no longer necessary, thankfully)
* Jonathan Blow for the language