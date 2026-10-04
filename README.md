# Raylib-d Template

A simple template for raylib-d projects.
It includes:

- One D file.
- Helper functions that accept D strings.
- Emscripten functions.
- A script that builds for the web.

## Example Project

An example with source code is available on [itch.io](https://kapendev.itch.io/k-merge-with-me).

[![dw](https://img.itch.zone/aW1hZ2UvNDc3MDEyNy8yODQ0MTI1OC5wbmc=/original/%2ByIKwH.png)](https://kapendev.itch.io/k-merge-with-me)

## Web Builds

Web builds can be made with a script called `build_web.d`.
Building for the web requires [LDC](https://github.com/ldc-developers/ldc/releases) and [Emscripten](https://emscripten.org/) (version `4.0.23` is recommended).
While installing LDC, unpack `ldc2-X.Y.Z-addon-emscripten.tar.xz` from the same [releases page](https://github.com/ldc-developers/ldc/releases) into the LDC installation folder.

To use the script, run:

```sh
dmd -run build_web.d
# Or: ldc2 -run build_web.d
# Or: ./build_web.d
```

API:

```
Usage:
  build_web.d [flags]
Flags:
  -betterc  Use the `-betterC` flag.
  -release  Use the `-release` flag.
  -build    Avoid emrun after a successful build.
```

### Uploading to itch.io

1. Open the web folder.
2. Select the `index.*` files and add them to a ZIP file.
3. Go to itch.io and create a new project.
4. Under "Kind of project", choose "HTML."
5. Upload the ZIP file and enable the option "This file will be played in the browser."

### Loading Assets

Use paths from the project root.
By default the packaged folder is `source`, so `source/app.d` is a valid path.
If an `assets` folder exists in the project folder, that is packaged instead, so `assets/map.csv` is a valid path.
