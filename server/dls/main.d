module dls.main;

import rt.dbg;
import str = rt.str;
import args = rt.args;
import mem = rt.memz;
import cjson = cjson;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;

import dls.io;
import dls.dcd;
import dls.initialize;
import dls.completion;
import dls.document_symbols;
import dls.definition;
//import dls.semantic_tokens;

version (linux)
    pragma(lib, "server/dls/libdcd.a");
else version(Windows)
    pragma(lib, "server/dls/dcd.lib");
else
    static assert(0, "platform not yet supported");


__gshared:

mem.ArenaAllocator arena;
char[] dbg;

extern(C) void* j_alloc(size_t sz) {
    return arena.alloc(sz).ptr;
}

extern(C) void j_free(void* ptr) {
}

extern(C) void main(int argc, char** argv) {
    arena = mem.ArenaAllocator.create(mem.c_allocator);

    // TODO: remove this
    //  - auto detect dmd/ldc
    //  - config for other folders

    version(linux)
    {
        string[3] importPaths = [
            "/usr/include/dlang/dmd/",
            "/usr/include/dmd/druntime/import/",
            "/usr/include/dmd/phobos/",
        ];
    }
    else version(Windows)
    {
        string[3] importPaths = [
            "c:/D/dmd2/src/druntime/import/",
            "c:/D/dmd2/src/phobos/",
        ];
    }
    else version(darwin)
    {
        static assert(0, "i need to investigate where to find the paths");
    }
    string[] extraImports;

    LINFO("args: {} -> {}", argc, argv);

    for (int i = 0; i < argc;i++)
    {
        auto arg = argv[i];
        auto argStr = arg[0 .. strlen(arg)];
        LINFO("arg: {} -> {}", i, argv[i]);
        if (mem.starts_with(argStr, "--imports="))
        {
            auto list = str.split_alloc(arena.allocator(), argStr[10 .. $], ",");
            if (list.length > 0)
            {
                extraImports = arena.allocator().alloc!(string)(list.length);
                for (int j = 0; j < list.length; j++)
                {
                    extraImports[j] = cast(string) list[j];
                }
            }
        }
    }


    dcd_init(importPaths);
    dcd_add_imports(extraImports);

    cjson.cJSON_Hooks hooks;
    hooks.malloc_fn = &j_alloc;
    hooks.free_fn = &j_free;
    cjson.cJSON_InitHooks(&hooks);

     //test
    //{
    //    cjson.cJSON* request = cjson.cJSON_Parse(TEST_DIDOPEN.ptr);
    //    handle_request(request);
    //}
    //{
    //    cjson.cJSON* request = cjson.cJSON_Parse(TEST_DIDCHANGE.ptr);
    //    handle_request(request);
    //}
    //{
    //    cjson.cJSON* request = cjson.cJSON_Parse(TEST_COMPLETION.ptr);
    //    handle_request(request);
    //}
    //{
    //    return;
    //}

    while (true) {
        auto len = parse_header();
        auto request = parse_content(arena.allocator(), len);
        if (!request) {
            LERRO("unnable to parse request");
            break;
        }
        handle_request(request);
        arena.dispose();
    }
}

size_t parse_header() {
    char[] buffer = arena.allocator().alloc!(char)(4096 * 10);
    size_t content_length = 0;
    buffer[] = '\0';
    while (true) {
        //LINFO("reading stdin..");
        fgets(buffer.ptr, cast(int) buffer.length, stdin);

        if (strcmp(buffer.ptr, "\r\n") == 0) { // End of header
            if (content_length == 0) {
                LERRO("buffer empty");
                exit(1);
            }

            //LINFO("header:\n{}", buffer);
            return content_length;
        }

        char* buffer_part = strtok(buffer.ptr, " ");
        if (strcmp(buffer_part, "Content-Length:") == 0) {
            buffer_part = strtok(null, "\n");
            content_length = atoi(buffer_part);
            //LINFO("content_length: {}", content_length);
        }
    }
    return 0;
}

cjson.cJSON* parse_content(mem.Allocator alloc, size_t content_length) {
    char[] buffer = alloc.alloc!(char)(content_length + 1);
    buffer[] = '\0';
    if (buffer == null) {
        LERRO("buffer null");
        exit(1);
    }
    size_t read_elements = fread(buffer.ptr, 1, content_length, stdin);
    if (read_elements != content_length) {
        LERRO("buffer size mismatch");
        exit(1);
    }
    buffer[content_length] = '\0';

    //LINFO("content:\n{}", buffer);

    auto request = cjson.cJSON_Parse(buffer.ptr);
    return request;
}

void handle_request(cjson.cJSON* request) {
    int id = -1;
    char* method;

    auto method_json = cjson.cJSON_GetObjectItem(request, "method");
    if (!cjson.cJSON_IsString(method_json)) {
        LERRO("not a str");
        exit(1);
    }
    method = method_json.valuestring;

    auto id_json = cjson.cJSON_GetObjectItem(request, "id");
    if (cjson.cJSON_IsNumber(id_json)) {
        id = id_json.valueint;
    }

    auto params_json = cjson.cJSON_GetObjectItem(request, "params");

     LINFO("request id: {} -> method: {}", id, method);

    // RPC
    if (strcmp(method, "initialize") == 0) {
        lsp_initialize(id);
    } else if (strcmp(method, "shutdown") == 0) {
        lsp_shutdown(id);
    } else if (strcmp(method, "exit") == 0) {
        lsp_exit();
    } else if (strcmp(method, "textDocument/didOpen") == 0) {
        lsp_sync_open(params_json);
    } else if (strcmp(method, "textDocument/didChange") == 0) {
        lsp_sync_change(params_json);
    } else if (strcmp(method, "textDocument/didClose") == 0) {
        lsp_sync_close(params_json);
    }
    else if(strcmp(method, "textDocument/documentSymbol") == 0) {
      lsp_document_symbol(id, params_json);
    }
    //else if(strcmp(method, "textDocument/definition") == 0) {
    //  lsp_goto_definition(id, params_json);
    //}
    else if (strcmp(method, "textDocument/completion") == 0) {
        lsp_completion(id, params_json);
    }
    else if (strcmp(method, "textDocument/definition") == 0) {
        lsp_definition(id, params_json);
    }
    //else if (strcmp(method, "textDocument/semanticTokens/full") == 0) {
    //    lsp_semantic_tokens(id, params_json, true);
    //}
    //else if (strcmp(method, "textDocument/semanticTokens/range") == 0) {
    //    lsp_semantic_tokens(id, params_json, false);
    //}
    else if (strcmp(method, "dls/imports") == 0) {
        lsp_imports(id, params_json);
    }
    else
    {
        LWARN("request '{}' not handled", method);
    }
}


void lsp_shutdown(int id) {
    LERRO("lsp_shutdown");
    lsp_send_response(id, null);
    //exit(0);
}

void lsp_exit() {
    LERRO("lsp_exit");
    exit(0);
}



void lsp_imports(int id, cjson.cJSON* params_json) {
    char* output = cjson.cJSON_Print(params_json);

    LINFO("lsp_imports:\n{}", output);
}


void lsp_sync_open(cjson.cJSON* params_json) {
    auto text_document_json = cjson.cJSON_GetObjectItem(params_json, "textDocument");

    auto uri_json = cjson.cJSON_GetObjectItem(text_document_json, "uri");
    char* uri = cjson.cJSON_GetStringValue(uri_json);

    auto text_json = cjson.cJSON_GetObjectItem(text_document_json, "text");
    char* text = cjson.cJSON_GetStringValue(text_json);

    if (uri == null || text == null) {
        LERRO("");
        exit(1);
    }

    BUFFER buffer = open_buffer(uri, text);
    //lsp_lint(buffer);
}
void lsp_sync_change(cjson.cJSON* params_json) {
    auto text_document_json = cjson.cJSON_GetObjectItem(params_json, "textDocument");

    auto uri_json = cjson.cJSON_GetObjectItem(text_document_json, "uri");
    char* uri = cjson.cJSON_GetStringValue(uri_json);

    auto content_changes_json = cjson.cJSON_GetObjectItem(params_json, "contentChanges");
    auto content_change_json = cjson.cJSON_GetArrayItem(content_changes_json, 0);
    auto text_json = cjson.cJSON_GetObjectItem(content_change_json, "text");
    char* text = cjson.cJSON_GetStringValue(text_json);

    if (uri == null || text == null) {
        LERRO("doc not found");
        exit(1);
    }

    BUFFER buffer = update_buffer(uri, text);
    //lsp_lint(buffer);
}

void lsp_sync_close(cjson.cJSON* params_json) {
    auto text_document_json = cjson.cJSON_GetObjectItem(params_json, "textDocument");

    auto uri_json = cjson.cJSON_GetObjectItem(text_document_json, "uri");
    char* uri = cjson.cJSON_GetStringValue(uri_json);

    if (uri == null) {
        LERRO("");
        exit(1);
    }

    close_buffer(uri);
    //lsp_lint_clear(uri);
}


DOCUMENT_LOCATION lsp_parse_document(cjson.cJSON* params_json) {
    DOCUMENT_LOCATION document;

    auto text_document_json = cjson.cJSON_GetObjectItem(params_json, "textDocument");
    auto uri_json = cjson.cJSON_GetObjectItem(text_document_json, "uri");
    document.uri = cjson.cJSON_GetStringValue(uri_json);
    if (document.uri == null) {
        LERRO("");
        exit(1);
    }

    auto position_json = cjson.cJSON_GetObjectItem(params_json, "position");
    auto line_json = cjson.cJSON_GetObjectItem(position_json, "line");
    if (!cjson.cJSON_IsNumber(line_json)) {
        LERRO("");
        exit(1);
    }
    document.line = line_json.valueint;
    auto character_json = cjson.cJSON_GetObjectItem(position_json, "character");
    if (!cjson.cJSON_IsNumber(character_json)) {
        LERRO("");
        exit(1);
    }
    document.character = character_json.valueint;

    return document;
}

void lsp_send_response(int id, cjson.cJSON* result) {
    auto response = cjson.cJSON_CreateObject();
    cjson.cJSON_AddStringToObject(response, "jsonrpc", "2.0");
    cjson.cJSON_AddNumberToObject(response, "id", id);
    if (result != null)
        cjson.cJSON_AddItemToObject(response, "result", result);
    else
        cjson.cJSON_AddNullToObject(response, "result" );

    char* output = cjson.cJSON_PrintUnformatted(response);
    cjson.cJSON_Minify(output);
    auto len = strlen(output);

    char[] buffer = arena.allocator().alloc!(char)(len + 512);
    buffer[] = '\0';

    sprintf(buffer.ptr, "Content-Length: %u\r\n\r\n%s\0", cast(uint) len, output);
    fwrite(buffer.ptr, 1, strlen(buffer.ptr), stdout);
    fflush(stdout);



    LINFO("sent:\n{}", buffer);
}


// HELPERS


cjson.cJSON* create_range(cjson.cJSON* obj, const(char)* id, Position s, Position e)
{
    auto range = cjson.cJSON_AddObjectToObject(obj, id);
    auto start = cjson.cJSON_AddObjectToObject(range, "start");
    auto end = cjson.cJSON_AddObjectToObject(range, "end");
    cjson.cJSON_AddNumberToObject(start, "line", s.line);
    cjson.cJSON_AddNumberToObject(start, "character", s.character);
    cjson.cJSON_AddNumberToObject(end, "line", e.line);
    cjson.cJSON_AddNumberToObject(end, "character", e.character);
    return range;
}

bool get_range(cjson.cJSON* obj, Position* start, Position* end)
{
    auto range_json = cjson.cJSON_GetObjectItem(obj, "range");
    auto start_json = cjson.cJSON_GetObjectItem(range_json, "start");
    auto end_json = cjson.cJSON_GetObjectItem(range_json, "end");
    {
        auto line_json = cjson.cJSON_GetObjectItem(start_json, "line");
        auto char_json = cjson.cJSON_GetObjectItem(start_json, "character");
        start.line = line_json.valueint;
        start.character = char_json.valueint;
    }
    {
        auto line_json = cjson.cJSON_GetObjectItem(end_json, "line");
        auto char_json = cjson.cJSON_GetObjectItem(end_json, "character");
        end.line = line_json.valueint;
        end.character = char_json.valueint;
    }
    return true;
}


int kind_to_lsp(ubyte k)
{
    switch(k)
    {
        case 'c': // class name
            return KClass;
        case 'i': // interface name
            return KInterface;
        case 's': // struct name
        case 'u': // union name
            return KStruct;
        case 'a': // array
        case 'A': // associative array
        case 'v': // variable name
            return KVariable;
        case 'm': // member variable
            return KField;
        case 'e': // enum member
            return KEnumMember;
        case 'k': // keyword
            return KKeyword;
        case 'f': // function
            return KFunction;
        case 'F': // UFCS function acts like a method
            return KMethod;
        case 'g': // enum name
            return KEnum;
        case 'P': // package name
        case 'M': // module name
            return KModule;
        case 'l': // alias name
            return KReference;
        case 't': // template name
        case 'T': // mixin template name
            return KProperty;
        case 'h': // template type parameter
        case 'p': // template variadic parameter
            return KTypeParameter;
        default:
            return KText;
    }
}

enum KText = 1;
enum KMethod = 2;
enum KFunction = 3;
enum KConstructor = 4;
enum KField = 5;
enum KVariable = 6;
enum KClass = 7;
enum KInterface = 8;
enum KModule = 9;
enum KProperty = 10;
enum KUnit = 11;
enum KValue = 12;
enum KEnum = 13;
enum KKeyword = 14;
enum KSnippet = 15;
enum KColor = 16;
enum KFile = 17;
enum KReference = 18;
enum KFolder = 19;
enum KEnumMember = 20;
enum KConstant = 21;
enum KStruct = 22;
enum KEvent = 23;
enum KOperator = 24;
enum KTypeParameter = 25;

enum TEST_DIDOPEN = `{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///home/ryuukk/tmp/fuck.d","languageId":"d","version":125,"text":"\n\n\nstruct State\n{\n    int aaaaaaaaaaaaaaa;\n    int bbbbbbbbbbbbbbb;\n    int ccccccccccccccc;\n}\n\n\n\nvoid main()\n{\n    State st;\n\n    st.aa\n}"}}}`;
enum TEST_DIDCHANGE = `{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///home/ryuukk/tmp/fuck.d","version":126},"contentChanges":[{"text":"\n\n\nstruct State\n{\n    int aaaaaaaaaaaaaaa;\n    int bbbbbbbbbbbbbbb;\n    int ccccccccccccccc;\n}\n\n\n\nvoid main()\n{\n    State st;\n\n    st.aaa\n}"}]}}`;
enum TEST_COMPLETION = `{"jsonrpc":"2.0","id":2,"method":"textDocument/completion","params":{"textDocument":{"uri":"file:///home/ryuukk/tmp/fuck.d"},"position":{"line":16,"character":10}}}`;
