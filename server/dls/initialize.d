module dls.initialize;

import rt.dbg;
import c = cjson;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;

import dls.main;




void lsp_initialize(int id) {
    auto result = c.cJSON_CreateObject();

    //auto capabilities = c.cJSON_AddObjectToObject(result, "capabilities");
    //c.cJSON_AddNumberToObject(capabilities, "textDocumentSync", 1);
    //c.cJSON_AddBoolToObject(capabilities, "hoverProvider", 1);
    //c.cJSON_AddBoolToObject(capabilities, "definitionProvider", 1);
    //c.cJSON_AddBoolToObject(capabilities, "documentSymbolProvider", 1);

    //auto serverInfo = c.cJSON_AddObjectToObject(result, "serverInfo");
    //c.cJSON_AddStringToObject(serverInfo, "name", "dls");
    //c.cJSON_AddStringToObject(serverInfo, "version", "0.0.1");


    auto capabilities = result.add_object("capabilities")
            .add_number("textDocumentSync", 1)
            .add_number("hoverProvider", 1)
            .add_number("definitionProvider", 1)
            .add_number("documentSymbolProvider", 1);

    //enable_semantice_tokens(capabilities);
    enable_completion(capabilities);

    auto serverInfo = result.add_object("serverInfo")
            .add_string("name", "dls")
            .add_string("version", "0.0.1");

    lsp_send_response(id, result);
}

void enable_completion(c.cJSON* capabilities)
{
    auto completion = c.cJSON_AddObjectToObject(capabilities, "completionProvider");
    c.cJSON_AddBoolToObject(completion, "resolveProvider", 0);

    const(char)*[6] tc = [ ".","=","/","*","+","-"];
    auto triggerCharacters = c.cJSON_CreateStringArray(tc.ptr, tc.length);
    c.cJSON_AddItemToObject(completion, "triggerCharacters", triggerCharacters);

    auto completionItem = c.cJSON_AddObjectToObject(completion, "completionItem");
    c.cJSON_AddBoolToObject(completionItem, "labelDetailsSupport", 1);
}

void enable_semantice_tokens(c.cJSON* capabilities) {
    const(char*)[27] tok_types = [
        "namespace",       // 0
        "type",            // 1
        "class",           // 2
        "enum",            // 3
        "interface",       // 4
        "struct",          // 5
        "typeParameter",   // 6
        "parameter",       // 7
        "variable",        // 8
        "property",        // 9
        "enumMember",      // 10
        "event",           // 11
        "function",        // 12
        "method",          // 13
        "macro",           // 14
        "keyword",         // 15
        "modifier",        // 16
        "comment",         // 17
        "string",          // 18
        "number",          // 19
        "regexp",          // 20
        "operator",        // 21
        "decorator",       // 22
        /// non standard token type
        "errorTag",
        /// non standard token type
        "builtin",
        /// non standard token type
        "label",
        /// non standard token type
        "keywordLiteral",
    ];
    const(char*)[12] tok_mods = [
        "declaration",
        "definition",
        "readonly",
        "static",
        "deprecated",
        "abstract",
        "async",
        "modification",
        "documentation",
        "defaultLibrary",
        // non standard token modifiers
        "generic",
        "_",
    ];

    auto semanticTokensProvider = c.cJSON_AddObjectToObject(capabilities, "semanticTokensProvider");
    c.cJSON_AddBoolToObject(semanticTokensProvider, "full", 1);
    c.cJSON_AddBoolToObject(semanticTokensProvider, "range", 0);

    auto legend = c.cJSON_AddObjectToObject(semanticTokensProvider, "legend");
    auto types = c.cJSON_CreateStringArray(tok_types.ptr, tok_types.length);
    auto mods = c.cJSON_CreateStringArray(tok_mods.ptr, tok_mods.length);
    c.cJSON_AddItemToObject(legend, "tokenTypes", types);
    c.cJSON_AddItemToObject(legend, "tokenModifiers", mods);
}

c.cJSON* add_object(c.cJSON* it, const(char)* name)
{
    return c.cJSON_AddObjectToObject(it, name);
}
c.cJSON* add_number(c.cJSON* it, const(char)* name, int value)
{
    c.cJSON_AddNumberToObject(it, name, value);
    return it;
}
c.cJSON* add_string(c.cJSON* it, const(char)* name, const(char)* value)
{
    c.cJSON_AddStringToObject(it, name, value);
    return it;
}
c.cJSON* add_bool(c.cJSON* it, const(char)* name, bool value)
{
    c.cJSON_AddBoolToObject(it, name, value);
    return it;
}