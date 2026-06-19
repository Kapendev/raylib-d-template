import raylib;

// The main loop. If true is returned, then the app will stop running.
bool update() {
    BeginDrawing();
    ClearBackground(Color(96, 96, 96, 255));
    scope (exit) EndDrawing();

    drawText("Hello world!", 32, 32, 40);
    return false;
}

// The initialization function.
void ready() {
    SetConfigFlags(ConfigFlags.FLAG_VSYNC_HINT | ConfigFlags.FLAG_WINDOW_RESIZABLE);
    InitWindow(1280, 720, "My Cool Title");
    SetTargetFPS(60);

    static void updateWindow(alias loopFunc)() {
        version (WebAssembly) {
            static void webLoopFunc() {
                if (loopFunc()) emscripten_cancel_main_loop();
            }
            emscripten_set_main_loop(&webLoopFunc, 0, true);
        } else {
            while (true) {
                if (WindowShouldClose() || loopFunc()) break;
            }
        }
    }

    updateWindow!(update);
    CloseWindow();
}

/// Draw text, but only if you are a PascalCase fan.
alias DrawText = drawText;

/// Draw text (using default font).
/// NOTE: fontSize work like in any drawing program but if fontSize is lower than font-base-size, then font-base-size is used.
/// NOTE: chars spacing is proportional to fontSize.
void drawText(const(char)[] text, int posX, int posY, int fontSize, Color color = Colors.WHITE, int textLineSpacing = 2) {
    enum defaultFontSize = 10; // Default Font chars height in pixel.
    if (fontSize < defaultFontSize) fontSize = defaultFontSize;
    drawText(GetFontDefault(), text, Vector2(posX, posY), fontSize, fontSize / defaultFontSize, color, textLineSpacing);
}

/// Draw text using Font.
/// NOTE: chars spacing is NOT proportional to fontSize.
void drawText(Font font, const(char)[] text, Vector2 position, float fontSize, float spacing, Color tint = Colors.WHITE, int textLineSpacing = 2) {
    if (font.texture.id == 0) font = GetFontDefault();
    auto textOffsetY = 0.0f;                     // Offset between lines (on linebreak '\n').
    auto textOffsetX = 0.0f;                     // Offset X to next character to draw.
    auto scaleFactor = fontSize / font.baseSize; // Character quad scaling factor.
    for (auto i = 0; i < text.length;) {
        auto codepointByteCount = 0;
        auto codepoint = GetCodepointNext(&text[i], &codepointByteCount);
        auto index = GetGlyphIndex(font, codepoint);
        if (codepoint == '\n') {
            textOffsetY += fontSize + textLineSpacing;
            textOffsetX = 0.0f;
        } else {
            if ((codepoint != ' ') && (codepoint != '\t')) {
                DrawTextCodepoint(font, codepoint, Vector2(position.x + textOffsetX, position.y + textOffsetY), fontSize, tint);
            }
            if (font.glyphs[index].advanceX == 0) {
                textOffsetX += font.recs[index].width * scaleFactor + spacing;
            } else {
                textOffsetX += font.glyphs[index].advanceX * scaleFactor + spacing;
            }
        }
        i += codepointByteCount;
    }
}

/// Draw text using Font and pro parameters (rotation).
void drawText(Font font, const(char)[] text, Vector2 position, Vector2 origin, float rotation, float fontSize, float spacing, Color tint = Colors.WHITE, int textLineSpacing = 2) {
    rlPushMatrix();
    rlTranslatef(position.x, position.y, 0.0f);
    rlRotatef(rotation, 0.0f, 0.0f, 1.0f);
    rlTranslatef(-origin.x, -origin.y, 0.0f);
    drawText(font, text, Vector2(0.0f, 0.0f), fontSize, spacing, tint, textLineSpacing);
    rlPopMatrix();
}

// Emscripten functions.
version (WebAssembly) {
    extern(C) @system nothrow @nogc
    void emscripten_set_main_loop(void* ptr, int fps, bool loop);
    extern(C) @system nothrow @nogc
    void emscripten_cancel_main_loop();
}

// -betterC trick.
version (D_BetterC) {
    extern(C) void main() { ready(); }
} else {
    void main() { ready(); }
}
