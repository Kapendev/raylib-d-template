#!/bin/env -S dmd -run

immutable string[] extraLdcFlags   = [];
immutable string[] extraOpendFlags = [];
immutable string[] extraEmccFlags  = [];

struct Flags {
    bool debugBuild = false; /// Can be used to make a debug build.
    bool gcBuild    = false; /// Can be used to enable GC features. This needs OpenD to work.
    bool dubBuild   = true;  /// Will use a DUB config to compile. More info inside the `doNoGcProject` function.
    bool justBuild  = false; /// Can be used to avoid emrun after a successful build.
    bool doNothing  = false; /// For testing the script without running emcc, dub, ...
}

struct CorePaths {
    string sourcePath = "source"; /// The source folder. Empty string = the current folder.
    string assetsPath = "assets"; /// The assets folder. Empty string = the source folder.
    string webPath    = "web";    /// The build folder for the web. Empty string = the current folder.
    string libPath;
    string emscriptenShellPath;
    string faviconPath;
    string outputPath;

    void tryToFindSourcePath() {
        sourcePath = "source";
        if (!sourcePath.exists) sourcePath = "src";
        if (!sourcePath.exists) sourcePath = ".";
    }

    void buildWebPaths() {
        libPath             = buildPath(webPath, "libraylib.web.a");
        emscriptenShellPath = buildPath(webPath, ".emscripten_shell.html");
        faviconPath         = buildPath(webPath, "favicon.ico");
        outputPath          = buildPath(webPath, "index.html");
    }
}

int main(string[] args) {
    auto flags = Flags();
    foreach (arg; args) {
        auto cleanArg = arg.stripLeft("-").stripLeft("-");
        static foreach (flagIndex, flagName; Flags.tupleof) {
            if (cleanArg.endsWith(flagName.stringof)) {
                flags.tupleof[flagIndex] = cleanArg.startsWith("no-") ? false : true;
            }
        }
    }
    if (flags.doNothing) {
        writeln("Nothing.");
        return 0;
    }

    auto corePaths = CorePaths();
    corePaths.tryToFindSourcePath();
    if (!corePaths.assetsPath.exists) corePaths.assetsPath = corePaths.sourcePath;
    if (!corePaths.webPath.exists) corePaths.webPath = ".";
    corePaths.buildWebPaths();

    if (!corePaths.libPath.exists) {
        writeln(`ERROR: Missing "`, corePaths.libPath, `" file.`);
        writeln(`Download the webassembly zip from "https://github.com/raysan5/raylib/releases" and extract it into the folder.`);
        return 1;
    }

    std.file.write(corePaths.emscriptenShellPath, emscriptenShell);
    auto faviconDummy = false;
    if (!corePaths.faviconPath.exists) {
        std.file.write(corePaths.faviconPath, "");
        faviconDummy = true;
    }

    void cleanFolder() {
        removeObjectFilesFromFolder(".");
        std.file.remove(corePaths.emscriptenShellPath);
        if (faviconDummy) std.file.remove(corePaths.faviconPath);
    }

    if (flags.gcBuild) {
        if (doGcProject(flags, corePaths)) {
            cleanFolder();
            return 1;
        }
    } else {
        if (doNoGcProject(flags, corePaths)) {
            cleanFolder();
            return 1;
        }
    }
    cleanFolder();

    return (flags.justBuild || !corePaths.outputPath.exists) ? 0 : runCmd([emrunName, corePaths.outputPath]).status;
}

int doGcProject(in Flags flags, in CorePaths corePaths) {
    enum moduleName      = "raylib";
    enum packageName     = "raylib-d";
    enum packageRepoLink = "https://github.com/schveiguy/raylib-d";

    auto packagePath = packageName;
    auto packageSourcePath = packageName;
    setPackagePaths(packagePath, packageSourcePath, packageName, moduleName, packageRepoLink, corePaths);
    auto isPackageOutsideSource = true;
    auto sourceFilePaths = getSourceFilePaths(isPackageOutsideSource, moduleName, packageSourcePath, corePaths);

    string[] cmdArgs = ["opend"];
    if (flags.debugBuild) {
        cmdArgs ~= "build";
    } else {
        cmdArgs ~= "publish";
    }
    cmdArgs ~= ["--target=emscripten", "-of" ~ corePaths.outputPath];
    cmdArgs ~= sourceFilePaths;
    cmdArgs.appendIncludePaths(packageSourcePath, isPackageOutsideSource, corePaths);
    cmdArgs.appendLinkerFlags(true, corePaths);
    cmdArgs ~= extraOpendFlags;

    auto result = runCmd(cmdArgs);
    if (result.status) writeln("NOTE: OpenD is available at: https://opendlang.org");
    return result.status;
}

int doNoGcProject(in Flags flags, in CorePaths corePaths) {
    enum moduleName      = "raylib";
    enum packageName     = "raylib-d";
    enum packageRepoLink = "https://github.com/schveiguy/raylib-d";
    enum dubConfigName   = "wasm";
    enum dubTargetName   = "game_wasm";
    enum ldc2            = "ldc2";

    auto packagePath = packageName;
    auto packageSourcePath = packageName;
    setPackagePaths(packagePath, packageSourcePath, packageName, moduleName, packageRepoLink, corePaths);
    auto isPackageOutsideSource = true;
    auto sourceFilePaths = getSourceFilePaths(isPackageOutsideSource, moduleName, packageSourcePath, corePaths);

    if (flags.dubBuild) {
        string[] cmdArgs = ["dub", "build", "--compiler=" ~ ldc2, "--arch=wasm32-emscripten", "--config", dubConfigName];
        if (!flags.debugBuild) cmdArgs ~= ["--build", "release"];
        if (runCmd(cmdArgs).status) return 1;
    } else {
        string[] cmdArgs = [ldc2, "-c", "-i", "-betterC", "-checkaction=halt", "-mtriple=wasm32-emscripten"];
        if (!flags.debugBuild) cmdArgs ~= "--release";
        cmdArgs ~= sourceFilePaths;
        cmdArgs ~= "-I=" ~ corePaths.sourcePath;
        cmdArgs ~= "-J=" ~ corePaths.assetsPath;
        cmdArgs ~= extraLdcFlags;
        if (runCmd(cmdArgs).status) return 1;
    }

    string[] cmdArgs = [emccName, "-o", corePaths.outputPath, corePaths.libPath];
    cmdArgs.appendLinkerFlags(false, corePaths);
    auto dubOutputPath = "";
    if (flags.dubBuild) {
        foreach (entry; dirEntries(".", SpanMode.shallow)) {
            auto path = entry.name;
            if (path.findStart(dubTargetName) != -1) {
                dubOutputPath = path;
                break;
            }
        }
        cmdArgs ~= dubOutputPath;
    } else {
        foreach (entry; dirEntries(".", SpanMode.shallow)) {
            // The build string is a hack to avoid issues with `dmd -run`.
            auto path = entry.name;
            if (path.endsWith(".o") && !path.baseName.startsWith("build")) cmdArgs ~= path;
        }
    }
    cmdArgs ~= extraEmccFlags;

    auto result = runCmd(cmdArgs);
    if (dubOutputPath.length) std.file.remove(dubOutputPath);
    return result.status;
}

void setPackagePaths(ref string packagePath, ref string packageSourcePath, string packageName, string moduleName, string packageRepoLink, in CorePaths corePaths) {
    if (!packagePath.exists) packagePath = buildPath(corePaths.sourcePath, moduleName);
    if (!packagePath.exists) packagePath = buildPath(corePaths.webPath, packageName);
    if (!packagePath.exists) packagePath = getPackagePathFromDub(packageName);
    if (!packagePath.exists && packageRepoLink.length) {
        packagePath = buildPath(corePaths.webPath, packagePath);
        runCmd(["git", "clone", "--depth", "1", packageRepoLink, buildPath(corePaths.webPath, packageName)]);
    }
    packageSourcePath = buildPath(packagePath, "source");
    if (!packageSourcePath.exists) packageSourcePath = buildPath(packagePath, "src");
    if (!packageSourcePath.exists) packageSourcePath = packagePath;
}

string[] getSourceFilePaths(ref bool isPackageOutsideSource, string packageName, string packageSourcePath, in CorePaths corePaths) {
    string[] sourceFilePaths;
    isPackageOutsideSource = true;
    foreach (entry; dirEntries(corePaths.sourcePath, SpanMode.breadth)) {
        auto path = entry.name;
        if (path.endsWith(".d")) {
            sourceFilePaths ~= path;
            if (path.startsWith(packageName)) isPackageOutsideSource = false;
        }
    }
    if (isPackageOutsideSource) {
        foreach (entry; dirEntries(packageSourcePath, SpanMode.breadth)) {
            auto path = entry.name;
            if (path.endsWith(".d")) {
                sourceFilePaths ~= path;
            }
        }
    }
    return sourceFilePaths;
}

string getPackagePathFromDub(string packageName, string packageSourceName = "source") {
    auto target = buildPath(packageName, packageSourceName);
    version (Windows) {
        target ~= `\"`;
    } else {
        target ~= `/"`;
    }

    auto content = runCmd(["dub", "describe"], false).output;
    auto lineIndex = size_t(0);
    foreach (i, c; content) {
        if (c != '\n') continue;
        auto line = content[lineIndex .. i].strip().strip(",");
        if (line.endsWith(target)) {
            return line[line.indexOf('"') + 1 .. $ - 1];
        }
        lineIndex = i + 1;
    }

    return "";
}

void appendIncludePaths(ref string[] cmdArgs, string packageSourcePath, bool isPackageOutsideSource, in CorePaths corePaths) {
    cmdArgs ~= "-I=" ~ corePaths.sourcePath;
    if (isPackageOutsideSource) {
        cmdArgs ~= "-I=" ~ packageSourcePath;
    }
}

void appendLinkerFlags(ref string[] cmdArgs, bool hasLinkerPrefix, in CorePaths corePaths) {
    auto startIndex = hasLinkerPrefix ? 0 : 3;
    cmdArgs ~= "-L=-DPLATFORM_WEB"[startIndex .. $];
    cmdArgs ~= "-L=-sEXPORTED_RUNTIME_METHODS=HEAPF32,requestFullscreen"[startIndex .. $];
    cmdArgs ~= "-L=-sUSE_GLFW=3"[startIndex .. $];
    cmdArgs ~= "-L=-sERROR_ON_UNDEFINED_SYMBOLS=0"[startIndex .. $];
    cmdArgs ~= "-L=-sINITIAL_MEMORY=67108864"[startIndex .. $];
    cmdArgs ~= "-L=-sALLOW_MEMORY_GROWTH=1"[startIndex .. $];
    cmdArgs ~= "-L=--shell-file"[startIndex .. $];
    cmdArgs ~= ("-L=" ~ corePaths.emscriptenShellPath)[startIndex .. $];
    cmdArgs ~= ("-L=" ~ corePaths.libPath)[startIndex .. $];
    // Check if the assets folder is empty because emcc will cry about it.
    if (corePaths.assetsPath.exists) {
        foreach (entry; dirEntries(corePaths.assetsPath, SpanMode.shallow)) {
            auto path = entry.name;
            if (path.exists) {
                cmdArgs ~= "-L=--preload-file"[startIndex .. $];
                cmdArgs ~= ("-L=" ~ corePaths.assetsPath)[startIndex .. $];
                break;
            }
        }
    }
}

void removeObjectFilesFromFolder(string folderPath) {
    foreach (entry; dirEntries(folderPath, SpanMode.shallow)) {
        auto path = entry.name;
        if (path.endsWith(".o")) std.file.remove(path);
    }
}

auto runCmd(string[] cmdArgs, bool canPrintOutput = true) {
    static if (false) {
        std.stdio.write("CMD:");
        foreach (arg; cmdArgs) std.stdio.write(" ", arg);
        writeln();
    } else {
        writeln("CMD: ", cmdArgs);
    }

    auto result = execute(cmdArgs);
    if (canPrintOutput) writeln(result.output);
    return result;
}

int findStart(const(char)[] str, const(char)[] item) {
    if (str.length < item.length || item.length == 0) return -1;
    foreach (i; 0 .. str.length - item.length + 1) {
        if (str[i .. i + item.length] == item) return cast(int) i;
    }
    return -1;
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

import std.stdio;
import std.string;
import std.path;
import std.file;
import std.process;

// ---
// Copyright 2026 Alexandros F. G. Kapretsos
// SPDX-License-Identifier: MIT
// Email: alexandroskapretsos@gmail.com
// Project: https://github.com/Kapendev/joka
// ---
