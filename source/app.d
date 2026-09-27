import raylib;

// The main loop. If true is returned, then the program will stop running.
bool update() {
    BeginDrawing();
    ClearBackground(Color(96, 96, 96, 255));
    scope (exit) EndDrawing();

    auto info = textFormat("Mouse: (%d %d)\nFPS: %d", GetMouseX(), GetMouseY(), GetFPS());
    drawText("Hello world!", 32, 32, 40);
    drawText(info, 32, 100, 40);
    drawTextCentered("UwU", GetScreenWidth() / 2, GetScreenHeight() / 2, 40);
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

// Emscripten functions that are needed for the web.
version (WebAssembly) {
    extern(C) @system nothrow @nogc {
        void emscripten_set_main_loop(void* ptr, int fps, bool loop);
        void emscripten_cancel_main_loop();
    }
}

// A `-betterC` trick.
version (D_BetterC) {
    extern(C) void main(int argc, char** argv) {
        ready();
    }
} else {
    void main() {
        ready();
    }
}

// Helper functions that mainly avoid C strings in an efficient way.
@trusted nothrow @nogc {
    /// Draw text (using default font).
    /// NOTE: fontSize work like in any drawing program but if fontSize is lower than font-base-size, then font-base-size is used.
    /// NOTE: chars spacing is proportional to fontSize.
    void drawText(const(char)[] text, int posX, int posY, int fontSize, Color color = Colors.WHITE, int textLineSpacing = 2) {
        enum defaultFontSize = 10;
        if (fontSize < defaultFontSize) fontSize = defaultFontSize;
        drawText(GetFontDefault(), text, Vector2(posX, posY), fontSize, fontSize / defaultFontSize, color, textLineSpacing);
    }

    /// Draw text using Font.
    /// NOTE: chars spacing is NOT proportional to fontSize.
    void drawText(Font font, const(char)[] text, Vector2 position, float fontSize, float spacing, Color tint = Colors.WHITE, int textLineSpacing = 2) {
        if (font.texture.id == 0) font = GetFontDefault();
        auto textOffsetY = 0.0f;
        auto textOffsetX = 0.0f;
        auto scaleFactor = fontSize / font.baseSize;
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

    /// Draw horizontally centered text (using default font).
    void drawTextCentered(const(char)[] text, int x, int y, int fontSize, Color color = Colors.WHITE, int textLineSpacing = 2) {
        drawText(text, x - measureText(text, fontSize, textLineSpacing) / 2, y, fontSize, color, textLineSpacing);
    }

    /// Draw horizontally centered text using Font.
    void drawTextCentered(Font font, const(char)[] text, Vector2 position, float fontSize, float spacing, Color tint = Colors.WHITE, int textLineSpacing = 2) {
        auto size = measureText(font, text, fontSize, spacing, textLineSpacing);
        drawText(font, text, Vector2(position.x - size.x / 2, position.y), fontSize, spacing, tint, textLineSpacing);
    }

    /// Measure string width for default font.
    int measureText(const(char)[] text, int fontSize, int textLineSpacing = 2) {
        auto textSize = Vector2(0.0f, 0.0f);
        if (GetFontDefault().texture.id != 0) {
            enum defaultFontSize = 10;
            if (fontSize < defaultFontSize) fontSize = defaultFontSize;
            auto spacing = fontSize / defaultFontSize;
            textSize = measureText(GetFontDefault(), text, fontSize, spacing, textLineSpacing);
        }
        return cast(int) textSize.x;
    }

    /// Measure string size for Font.
    Vector2 measureText(Font font, const(char)[] text, float fontSize, float spacing, int textLineSpacing = 2) {
        auto textSize = Vector2(0.0f, 0.0f);
        if ((font.texture.id == 0) || (text == null) || (text[0] == '\0')) return textSize;

        auto size            = cast(int) text.length;
        auto tempByteCounter = 0;
        auto byteCounter     = 0;
        auto textWidth       = 0.0f;
        auto tempTextWidth   = 0.0f;
        auto textHeight      = fontSize;
        auto scaleFactor     = fontSize / cast(float) font.baseSize;
        auto letter          = 0;
        auto index           = 0;

        for (auto i = 0; i < size;) {
            auto codepointByteCount = 0;
            byteCounter++;
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

    static char[1024] _textFormatBuffer = void;

    /// Formatting of text with variables to 'embed'.
    /// WARNING: String returned will expire after this function is called MAX_TEXTFORMAT_BUFFERS times.
    const(char)[] textFormat(A...)(const(char)[] text, A args) {
        foreach (i; 0 .. text.length) _textFormatBuffer[i] = text[i];
        _textFormatBuffer[text.length] = '\0';
        auto strz = TextFormat(_textFormatBuffer.ptr, args);
        auto strzLength = 0U;
        while (strz[strzLength]) strzLength += 1;
        return strz[0 .. strzLength];
    }

    /// Load texture from file into GPU memory (VRAM).
    Texture2D loadTexture(const(char)[] path) {
        return LoadTexture(textFormat(path).ptr);
    }

    /// Load image from file into CPU memory (RAM).
    Image loadImage(const(char)[] path) {
        return LoadImage(textFormat(path).ptr);
    }

    /// Load font from file into GPU memory (VRAM).
    Font loadFont(const(char)[] path) {
        return LoadFont(textFormat(path).ptr);
    }

    /// Load wave data from file.
    Wave loadWave(const(char)[] path) {
        return LoadWave(textFormat(path).ptr);
    }

    /// Load sound from file.
    Sound loadSound(const(char)[] path) {
        return LoadSound(textFormat(path).ptr);
    }

    /// Load music stream from file.
    Music loadMusic(const(char)[] path) {
        return LoadMusicStream(textFormat(path).ptr);
    }

    /// Load model from files (meshes and materials).
    Model loadModel(const(char)[] path) {
        return LoadModel(textFormat(path).ptr);
    }

    /// Load shader from files and bind default locations.
    Shader loadShader(const(char)[] vs, const(char)[] fs) {
        return LoadShader(textFormat(vs).ptr, textFormat(fs).ptr);
    }
}
