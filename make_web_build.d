#!/bin/env -S dmd -run

int doBasicProject() {
    return 0;
}

int doGcProject() {
    /*
    // Both DUB and no-DUB projects work the same because I don't care and you should vendor things anyway imo lololol.
    // The are some hacks here. One of them is that we need to have the package folders of parin.

    IStr parinPackagePath = "parin_package";
    if (!parinPackagePath.isX) parinPackagePath = join(webDir, "parin_package");
    if (!parinPackagePath.isX) cmd("git", "clone", "--depth", "1", "https://github.com/Kapendev/parin", parinPackagePath); // Could be removed, but I think most poeple don't care and just want to build something.
    auto parinPackageSourcePath = join(parinPackagePath, "source");

    auto webPackagePath = join(parinPackagePath, "packages", "web");
    auto webPackageSourcePath = join(webPackagePath, "source");

    auto hasParinInSource = false;
    auto hasJokaInSource = false;
    IStr[] files;
    foreach (path; ls(sourceDir, true)) {
        if (path.findEnd("_package") != -1) continue;
        if (path.findStart("parin") != -1 && path.endsWith(".d")) {
            hasParinInSource = true;
            files ~= path;
            continue;
        }
        if (path.endsWith(".d")) files ~= path;
    }
    if (!hasParinInSource) {
        foreach (path; ls(parinPackageSourcePath, true)) if (path.endsWith(".d")) files ~= path;
    }

    IStr[] args = ["opend"];
    if (isReleaseBuild) args ~= "publish";
    else args ~= "build";
    args ~= ["--target=emscripten", "-of" ~ outputFile];
    // The hack part.
    args ~= files;
    args ~= "-I=" ~ sourceDir;
    if (!isSimpProject) {
        args ~= "-I=" ~ parinPackageSourcePath;
    }
    // The good part.
    args ~= "-L=" ~ libFile;
    args ~= "-L=-L" ~ webPackageSourcePath;
    args ~= "-L=-sEXPORTED_RUNTIME_METHODS=HEAPF32,requestFullscreen";
    args ~= "-L=-DPLATFORM_WEB";
    args ~= "-L=-sUSE_GLFW=3";
    args ~= "-L=-sERROR_ON_UNDEFINED_SYMBOLS=0";
    args ~= "-L=-sINITIAL_MEMORY=67108864";
    args ~= "-L=-sALLOW_MEMORY_GROWTH=1";
    args ~= "-L=--shell-file";
    args ~= "-L=" ~ shellFile;
    // Check if the assets folder is empty because emcc will cry about it.
    if (assetsDir.isX) {
        foreach (path; ls(assetsDir, true)) {
            if (path.isF) {
                args ~= "-L=--preload-file";
                args ~= "-L=" ~ assetsDir;
                break;
            }
        }
    }
    if (isRlProject) {
        foreach (f; cflagsExtraForRl) args ~= "-L=" ~ f;
    }
    auto result = cmd(args);
    clear(".", ".o");
    return result;
    */
    return 0;
}

int main(string[] args) {
    import std.stdio;
    import std.path;
    import std.file;
    import std.process;

    auto flags = Flags();
    foreach (arg; args) {
        static foreach (flagIndex, flagName; Flags.tupleof) {
            if (arg == flagName.stringof) flags.tupleof[flagIndex] = true;
        }
    }

    auto sourcePath = "source";
    if (!sourcePath.exists) sourcePath = "src";
    if (!sourcePath.exists) sourcePath = ".";
    auto webPath = "web";
    if (!webPath.exists) webPath = ".";

    auto libPath = "libraylib.a";
    if (!libPath.exists) {
        writeln("Missing: libraylib.a");
        writeln("Can be downloaded from: https://github.com/raysan5/raylib/releases (search for raylib-X.Y_webassembly.zip)");
        return 1;
    }

    auto emscriptenShellPath = "temp_emscripten_shell.html";
    std.file.write(emscriptenShell, emscriptenShellPath);
    scope (exit) std.file.remove(emscriptenShellPath);

    auto faviconPath = buildPath(webPath, "favicon.ico");
    auto faviconDummy = false;
    if (!faviconPath.exists) {
        std.file.write(faviconPath, "");
        faviconDummy = true;
    }

    auto outputPath = buildPath(webPath, "index.html");

    /* clear(".", ".o"); */
    if (flags.isGcProject) {
        if (doGcProject()) return 1;
    } else {
        if (doBasicProject()) return 1;
    }
    /* clear(".", ".o"); */
    if (faviconDummy) std.file.remove(faviconPath);
    return flags.justBuild ? 0 : execute([emrunName, outputPath]).status;
}

struct Flags {
    bool isDebugBuild;
    bool isGcProject;
    bool justBuild = true;
}

version (Windows) {
    enum emrunName = "emrun.bat";
    enum emccName = "emcc.bat";
} else {
    enum emrunName = "emrun";
    enum emccName = "emcc";
}

enum emscriptenShell = `
<!doctype html>
<html lang="EN-us">
<head>
    <title>game</title>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width">
    <style>
        body { margin: 0px; overflow: hidden; }
        canvas.emscripten { border: 0px none; background-color: black; }

        loading {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            display: flex; /* Center content horizontally and vertically */
            justify-content: center;
            align-items: center;
            background-color: rgba(0, 0, 0, 0.5); /* Semi-transparent background */
            z-index: 100; /* Ensure loading indicator sits above content */
        }

        .spinner {
            border: 16px solid #c0c0c0; /* Big */
            border-top: 16px solid #343434; /* Small */
            border-radius: 50%;
            width: 120px;
            height: 120px;
            animation: spin 2s linear infinite;
        }

        .center {
            position: fixed;
            inset: 0px;
            width: 120px;
            height: 120px;
            margin: auto;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        canvas {
            display: none; /* Initially hide the canvas */
        }
    </style>
</head>
<body>
    <div id="loading">
        <div class="center">
            <div class="spinner"></div>
        </div>
    </div>
    <canvas class=emscripten id=canvas oncontextmenu=event.preventDefault() tabindex=-1></canvas>
    <p id="output" />
    <script>
        var Module = {
            canvas: (function() {
                var canvas = document.getElementById('canvas');
                return canvas;
            })(),
            preRun: [function() {
                // Show loading indicator
                document.getElementById("loading").style.display = "block";
            }],
            postRun: [function() {
                // Hide loading indicator and show canvas
                document.getElementById("loading").style.display = "none";
                document.getElementById("canvas").style.display = "block";
            }]
        };
    </script>
    {{{ SCRIPT }}}
</body>
</html>
`[1 .. $ - 1];
