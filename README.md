# Raylib-d Template

Building for the web requires [Emscripten](https://emscripten.org/) (version `4.0.23` is recommended), and is done with a build script called `build_web.d`.
It works like this:

```sh
dmd -run build_web.d
# Or: ldc2 -run build_web.d
# Or: ./build_web.d
```

Projects requiring the D runtime can be built using the `-gcBuild` flag provided by the build script.
This flag also requires [OpenD](https://opendlang.org/index.html).
Note that exceptions are not supported and that currently some DUB related limitations apply like having to include all dependencies inside the source folder.
Make sure `opend install xpack-emscripten` has been run at least once before using it.

Example:

```sh
dmd -run build_web.d -gcBuild
# Or: ldc2 -run build_web.d -gcBuild
# Or: ./build_web.d -gcBuild
```

Available flags:

```d
struct Flags {
    bool debugBuild   = false; /// Can be used to make a debug build.
    bool gcBuild      = false; /// Can be used to enable GC features. This needs OpenD to work.
    bool justBuild    = false; /// Can be used to avoid `emrun` after a successful build.
    bool buildWithDub = true;  /// Will use a DUB config to compile. More info inside the `doNoGcProject` function.
}
```
