# Jai Hello World example for Raspberry Pi

This repo serves as an example Jai project for the Raspberry Pi (64-bit). The LLVM backend is used to target the machine, and various hacks to Jai's built-in modules are needed to get basic support working somewhat decently since ARM64 is not currently a first-class target.

## Setup

I recommend storing Jon's Jai beta releases in a Git repo. You can then make a new branch just for working with the Raspberry Pi hacks you'll need to install. From there, in the root of the Jai release folder, do:

```sh
git apply --ignore-whitespace /path/to/jai-module-hacks.patch
```

Now, you will need a way to compile C/C++ for the target. In my experience, I was having trouble compiling myself a GCC cross-toolchain that supports the Raspberry Pi with the correct GlibC version that Raspbian 64-bit currently uses (the `aarc64-linux-gnu-gcc` from my distro's package manager used a too-new GlibC version...). Maybe you will have more luck with this than I do with [the script I tried to use](https://gist.github.com/TheGag96/8d93fbf8125292b5da6a9e3d40e4548a) to build that. Without that, you won't be able to fully link an executable on your machine directly. However, my workaround so far was just to compile an object file with all of the Jai stuff on it and link it on the target (see [below](#Building)).

You'll need it first to build `stb_sprintf` as a dependency, so navigate to `modules/stb_sprintf` in the Jai release folder. In `build.jai`, there's a compile command you may need to edit to suit what toolchain you have. (It seems like even having a partially-working `aarch64` cross GCC is enough to compile a working `stb_sprintf` for our needs.)

```sh
jai build.jai - linux arm64
```

## Building

If you want to link an executable yourself, set `LINK_EXECUTABLE_ON_THIS_MACHINE` to `true` in `first.jai` and then do:

```sh
jai first.jai
```

If you need to link manually on the target, you'll need to compile, take the `jai-pi.o` file that the compilation produced, bring it and `stb_sprintf.a` over to your Raspberry Pi, then do:

```sh
aarc64-linux-gnu-gcc jai-pi.o stb_sprintf.a -pthread -o jai-pi
```

And that should do it. Hopefully as time goes on, this situation will improve and this README can have a lot fewer words in it!

## Thanks to...

* @ctp and @ctpeepee in the Discord server for helping with the module hacks
* [tsoding](https://github.com/tsoding) for the metaprogram scripts that let you report and strip out all uses of inline assembly
* Jonathan Blow for the language