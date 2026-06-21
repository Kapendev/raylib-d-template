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
            extern(C) static void webLoopFunc() {
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
/// Measure text, but only if you are a PascalCase fan.
alias MeasureText = measureText;

/// Draw text (using default font).
/// NOTE: fontSize work like in any drawing program but if fontSize is lower than font-base-size, then font-base-size is used.
/// NOTE: chars spacing is proportional to fontSize.
@trusted nothrow @nogc
void drawText(const(char)[] text, int posX, int posY, int fontSize, Color color = Colors.WHITE, int textLineSpacing = 2) {
    enum defaultFontSize = 10; // Default Font chars height in pixel.
    if (fontSize < defaultFontSize) fontSize = defaultFontSize;
    drawText(GetFontDefault(), text, Vector2(posX, posY), fontSize, fontSize / defaultFontSize, color, textLineSpacing);
}

/// Draw text using Font.
/// NOTE: chars spacing is NOT proportional to fontSize.
@trusted nothrow @nogc
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
@trusted nothrow @nogc
void drawText(Font font, const(char)[] text, Vector2 position, Vector2 origin, float rotation, float fontSize, float spacing, Color tint = Colors.WHITE, int textLineSpacing = 2) {
    rlPushMatrix();
    rlTranslatef(position.x, position.y, 0.0f);
    rlRotatef(rotation, 0.0f, 0.0f, 1.0f);
    rlTranslatef(-origin.x, -origin.y, 0.0f);
    drawText(font, text, Vector2(0.0f, 0.0f), fontSize, spacing, tint, textLineSpacing);
    rlPopMatrix();
}

/// Measure string width for default font.
int measureText(const(char)[] text, int fontSize, int textLineSpacing = 2) {
    auto textSize = Vector2(0.0f, 0.0f);
    // Check if default font has been loaded.
    if (GetFontDefault().texture.id != 0) {
        auto defaultFontSize = 10; // Default Font glyphs height in pixel.
        if (fontSize < defaultFontSize) fontSize = defaultFontSize;
        auto spacing = fontSize / defaultFontSize;
        textSize = measureText(GetFontDefault(), text, fontSize, spacing, textLineSpacing);
    }
    return cast(int) textSize.x;
}

/// Measure string size for Font.
Vector2 measureText(Font font, const(char)[] text, float fontSize, float spacing, int textLineSpacing = 2) {
    auto textSize = Vector2(0.0f, 0.0f);
    // Security check.
    if ((font.texture.id == 0) || (text == null) || (text[0] == '\0')) return textSize;
    // Get size in bytes of text.
    int size = cast(int) text.length;
    // Used to count longer text line num chars.
    int tempByteCounter = 0;
    int byteCounter     = 0;
    float textWidth     = 0.0f;
    // Used to count longer text line width.
    float tempTextWidth = 0.0f;
    float textHeight    = fontSize;
    float scaleFactor   = fontSize / cast(float) font.baseSize;
    // Current character.
    int letter = 0;
    // Index position in sprite font.
    int index = 0;

    for (int i = 0; i < size;) {
        byteCounter++;
        int codepointByteCount = 0;
        letter = GetCodepointNext(&text[i], &codepointByteCount);
        index = GetGlyphIndex(font, letter);
        i += codepointByteCount;

        if (letter != '\n') {
            if (font.glyphs[index].advanceX > 0) textWidth += font.glyphs[index].advanceX;
            else textWidth += (font.recs[index].width + font.glyphs[index].offsetX);
        } else {
            if (tempTextWidth < textWidth) tempTextWidth = textWidth;
            byteCounter = 0;
            textWidth = 0;
            textHeight += fontSize + textLineSpacing;
        }
        if (tempByteCounter < byteCounter) tempByteCounter = byteCounter;
    }

    if (tempTextWidth < textWidth) tempTextWidth = textWidth;
    textSize.x = tempTextWidth * scaleFactor + ((tempByteCounter - 1) * spacing);
    textSize.y = textHeight;
    return textSize;
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
