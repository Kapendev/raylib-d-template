# Raylib-d Template

Building for the web requires [Emscripten](https://emscripten.org/) (version 4.0.23 is recommended) and [OpenD](https://opendlang.org/).
Make sure `opend install xpack-emscripten` has been run at least once before using the build script.

Using the build script:

```sh
dmd -run build_web.d
# Or: ldc2 -run build_web.d
# Or: ./build_web.d
```
