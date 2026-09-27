# Raylib-d Template

A simple project template for raylib.
It includes:

- One D file that includes everything.
- Helper functions that take D strings.
- Emscripten functions.
- A script that builds for the web.

## Example Project

An example is available on [itch.io](https://kapendev.itch.io/k-merge-with-me).

## How do I make a web build?

Web builds can be made with a script called `build_web.d`.
Building for the web requires [LDC](https://github.com/ldc-developers/ldc/releases) and [Emscripten](https://emscripten.org/) (version `4.0.23` is recommended).
While installing LDC, make sure to also install `ldc2-X.Y.Z-addon-emscripten.tar.xz`.

To use the script, run:

```sh
dmd -run build_web.d
# Or: ldc2 -run build_web.d
# Or: ./build_web.d
```

```
Usage:
  build_web.d [flags]
Flags:
  -betterc  Use the `-betterC` flag.
  -release  Use the `-release` flag.
  -build    Avoid emrun after a successful build.
```

## How do I upload web builds to itch.io?

1. Open the web folder.
2. Select these files and add them to a ZIP file:

    ```
    index.data
    index.html
    index.js
    index.wasm
    ```

3. Go to itch.io and create a new project.
4. Under "Kind of project", choose "HTML."
5. Upload the ZIP file.
6. Enable the option "This file will be played in the browser."
7. Save the changes.

## How do I load assets with web builds?

Use paths from the project root.
By default the packaged folder is `source`, so `source/app.d` is a valid path.
If an `assets` folder exists in the project folder, that is packaged instead, so `assets/map.csv` is a valid path.
