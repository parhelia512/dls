module dls.io;

import rt.dbg;
import rt.filesystem;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;

enum BUFFER_LENGTH = 128;

struct DOCUMENT_LOCATION {
    const (char) * uri;
    int line;
    int character;
}

struct BUFFER {
    char* uri;
    char* content;
}

__gshared BUFFER[BUFFER_LENGTH] buffers;
__gshared int first_empty_buf;

BUFFER open_buffer(const char * uri, const char * content) {
    if (first_empty_buf >= BUFFER_LENGTH) {
        LERRO("");
        exit(1);
    }


    if (content == null)
    {
        LWARN("buffer '{}' doesn't exist, reading it now", uri);
        // read it
        File file;
        auto exist = file.open(uri[0 .. strlen(uri)]);
        if (!exist)
        {
            LERRO("file: '{}' doesn't exist", uri);
            return BUFFER.init;
        }
        auto s = file.size();
        auto b = cast(ubyte*) malloc(s + 1);
        b[s] = 0;
        file.read(b, s);
        buffers[first_empty_buf].uri = strdup(uri);
        buffers[first_empty_buf].content = cast(char*) b;
    }
    else
    {
        buffers[first_empty_buf].uri = strdup(uri);
        buffers[first_empty_buf].content = strdup(content);
    }
    return buffers[first_empty_buf++];
}

BUFFER update_buffer(const char * uri, const char * content) {
    for (int i = 0; i < first_empty_buf; i++) {
        if (strcmp(buffers[i].uri, uri) == 0) {
            free(buffers[i].content);
            buffers[i].content = strdup(content);
            return buffers[i];
        }
    }
    LERRO("");
    exit(1);
}
BUFFER get_buffer(const char * uri) {
    for (int i = 0; i < first_empty_buf; i++) {
        if (strcmp(buffers[i].uri, uri) == 0) {
            return buffers[i];
        }
    }
    LERRO("no fucks");
    exit(1);
}

bool has_buffer(const char * uri) {
    for (int i = 0; i < first_empty_buf; i++) {
        if (strcmp(buffers[i].uri, uri) == 0) {
            return true;
        }
    }
    return false;
}

BUFFER get_or_open_buffer(const char* uri)
{
    for (int i = 0; i < first_empty_buf; i++) {
        if (strcmp(buffers[i].uri, uri) == 0) {
            return buffers[i];
        }
    }
    return open_buffer(uri, null);
}

void close_buffer(const char * uri) {
    for (int i = 0; i < first_empty_buf; i++) {
        if (strcmp(buffers[i].uri, uri) == 0) {
            free(buffers[i].uri);
            free(buffers[i].content);
            for (int j = i; j < first_empty_buf - 1; j++) {
                buffers[j] = buffers[j + 1];
            }
            --first_empty_buf;
            return;
        }
    }
    LERRO("no fucks");
    exit(1);
}


void truncate_string(char * text, int line, int character) {
    uint position = 0;
    for (int i = 0; i < line; i++) {
        position += strcspn(text + position, "\n") + 1;
    }
    position += character;

    if (position >= strlen(text)) {
        return;
    }

    while (isalnum( * (text + position))) {
        ++position;
    }
    text[position] = '\0';
}

size_t[2] lineByteRangeAt(string text, uint line) {
    size_t start = 0;
    size_t index = 0;
    while (line > 0 && index < text.length) {
        const c = text.ptr[index++];
        if (c == '\n') {
            line--;
            start = index;
        }
    }
    // if !found
    if (line != 0)
        return [0, 0];

    int end = -1;

    for (size_t i = start; i < text.length; i++)
        if (text[i] == '\n') {
            end = cast(int) i;
            break;
        }
    if (end == -1)
        end = cast(int) text.length;
    else
        end++;

    return [start, end];
}
pragma(inline, true) void utf16DecodeUtf8Length(A, B)(char c, ref A utf16Index,
    ref B utf8Index) {
    switch (c & 0b1111_0000) {
    case 0b1110_0000:
        // assume valid encoding (no wrong surrogates)
        utf16Index++;
        utf8Index += 3;
        break;
    case 0b1111_0000:
        utf16Index += 2;
        utf8Index += 4;
        break;
    case 0b1100_0000:
    case 0b1101_0000:
        utf16Index++;
        utf8Index += 2;
        break;
    default:
        utf16Index++;
        utf8Index++;
        break;
    }
}

int positionToBytes(string text, int line, int character) {
    int index = 0;
    while (index < text.length && line > 0)
        if (text.ptr[index++] == '\n')
            line--;

    while (index < text.length && character > 0) {
        auto c = text.ptr[index];
        if (c == '\n')
            break;
        size_t utf16Size;
        utf16DecodeUtf8Length(c, utf16Size, index);
        if (utf16Size < character)
            character -= utf16Size;
        else
            character = 0;
    }
    return index;
}


struct Position
{
    size_t line;
    size_t character;

    int opCmp(const Position other) const
    {
        if (line < other.line)
            return -1;
        if (line > other.line)
            return 1;
        if (character < other.character)
            return -1;
        if (character > other.character)
            return 1;
        return 0;
    }
}
Position bytesToPosition(string text, size_t bytes)
{
    if (bytes > text.length)
        bytes = text.length;
    auto part = text.ptr[0 .. bytes];
    size_t lastNl = -1;
    Position ret;
    foreach (i; 0 .. bytes)
    {
        if (part.ptr[i] == '\n')
        {
            ret.line++;
            lastNl = i;
        }
    }
    ret.character = cast(uint)(cast(const(char)[]) part[lastNl + 1 .. $]).countUTF16Length;
    return ret;
}

size_t countUTF16Length(scope const(char)[] text)
{
    size_t offset;
    size_t index;
    while (index < text.length)
    {
        const c = (() @trusted => text.ptr[index++])();
        if (cast(byte)c >= -0x40) offset++;
        if (c >= 0xf0) offset++;
    }
    return offset;
}