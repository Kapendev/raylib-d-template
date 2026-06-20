#!/bin/env -S dmd -run

int main(string[] args) {
    auto flags = Flags();
    foreach (arg; args) {
        static foreach (flagIndex, flagName; Flags.tupleof) {
            if (arg == flagName.stringof) flags.tupleof[flagIndex] = true;
        }
    }

    auto corePaths = CorePaths();
    if (!corePaths.sourcePath.exists) corePaths.sourcePath = "src";
    if (!corePaths.sourcePath.exists) corePaths.sourcePath = ".";
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

    if (doGcProject(flags, corePaths)) return 1;
    removeObjectFilesFromFolder(".");
    std.file.remove(corePaths.emscriptenShellPath);
    if (faviconDummy) std.file.remove(corePaths.faviconPath);

    return (flags.justBuild || !corePaths.outputPath.exists) ? 0 : runCmd([emrunName, corePaths.outputPath]).status;
}

int doGcProject(in Flags flags, in CorePaths corePaths) {
    enum packageName = "raylib-d";
    enum packageLink = "https://github.com/schveiguy/raylib-d";

    auto packagePath = packageName;
    if (!packagePath.exists) packagePath = buildPath(corePaths.webPath, packagePath);
    if (!packagePath.exists) packagePath = getPathFromDub(packageName);
    if (!packagePath.exists) {
        packagePath = buildPath(corePaths.webPath, packagePath);
        runCmd(["git", "clone", "--depth", "1", packageLink, packagePath]);
    }
    auto packageSourcePath = buildPath(packagePath, "source");
    if (!packageSourcePath.exists) packageSourcePath = buildPath(packagePath, "src");
    if (!packageSourcePath.exists) packageSourcePath = packagePath;

    string[] sourceFilePaths;
    auto isPackageOutsideSource = true;
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

    string[] cmdArgs = ["opend"];
    if (flags.isDebugBuild) {
        cmdArgs ~= "build";
    } else {
        cmdArgs ~= "publish";
    }
    cmdArgs ~= ["--target=emscripten", "-of" ~ corePaths.outputPath];
    cmdArgs ~= sourceFilePaths;
    cmdArgs ~= "-I=" ~ corePaths.sourcePath;
    if (isPackageOutsideSource) {
        cmdArgs ~= "-I=" ~ packageSourcePath;
    }
    cmdArgs.appendLinkerFlags(true, corePaths.emscriptenShellPath);
    cmdArgs ~= "-L=" ~ corePaths.libPath;
    // Check if the assets folder is empty because emcc will cry about it.
    if (corePaths.assetsPath.exists) {
        foreach (entry; dirEntries(corePaths.assetsPath, SpanMode.shallow)) {
            auto path = entry.name;
            if (path.exists) {
                cmdArgs ~= "-L=--preload-file";
                cmdArgs ~= "-L=" ~ corePaths.assetsPath;
                break;
            }
        }
    }
    auto result = runCmd(cmdArgs);
    if (result.status) writeln("NOTE: OpenD is available at: https://opendlang.org");
    return result.status;
}

void appendLinkerFlags(ref string[] cmdArgs, bool hasLinkerPrefix, string emscriptenShellPath) {
    auto startIndex = hasLinkerPrefix ? 0 : 3;
    cmdArgs ~= "-L=-DPLATFORM_WEB"[startIndex .. $];
    cmdArgs ~= "-L=-sEXPORTED_RUNTIME_METHODS=HEAPF32,requestFullscreen"[startIndex .. $];
    cmdArgs ~= "-L=-sUSE_GLFW=3"[startIndex .. $];
    cmdArgs ~= "-L=-sERROR_ON_UNDEFINED_SYMBOLS=0"[startIndex .. $];
    cmdArgs ~= "-L=-sINITIAL_MEMORY=67108864"[startIndex .. $];
    cmdArgs ~= "-L=-sALLOW_MEMORY_GROWTH=1"[startIndex .. $];
    cmdArgs ~= "-L=--shell-file"[startIndex .. $];
    cmdArgs ~= ("-L=" ~ emscriptenShellPath)[startIndex .. $];
}

string getPathFromDub(string packageName, string packageSourceName = "source") {
    auto target = buildPath(packageName, packageSourceName);
    version (Windows) {
        target ~= `\"`;
    } else {
        target ~= `/"`;
    }

    auto content = runCmd(["dub", "describe"]).output;
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

void removeObjectFilesFromFolder(string folderPath) {
    foreach (entry; dirEntries(folderPath, SpanMode.shallow)) {
        auto path = entry.name;
        if (path.endsWith(".o")) std.file.remove(path);
    }
}

auto runCmd(string[] cmdArgs) {
    writeln("CMD:", cmdArgs);
    auto result = execute(cmdArgs);
    if (result.status) writeln("\n", result.output, "\n");
    return result;
}

struct Flags {
    // bool isGcProject;
    bool isDebugBuild;
    bool justBuild;
}

struct CorePaths {
    string sourcePath = "source";
    string assetsPath = "assets";
    string webPath    = "web";
    string libPath;
    string emscriptenShellPath;
    string faviconPath;
    string outputPath;

    void buildWebPaths() {
        libPath             = buildPath(webPath, "libraylib.web.a");
        emscriptenShellPath = buildPath(webPath, ".emscripten_shell.html");
        faviconPath         = buildPath(webPath, "favicon.ico");
        outputPath          = buildPath(webPath, "index.html");
    }
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
