module dls.initialize;

import rt.dbg;
import cjson = cjson;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;

import dls.main;




void lsp_initialize(int id) {
    auto result = cjson.cJSON_CreateObject();

    auto capabilities = cjson.cJSON_AddObjectToObject(result, "capabilities");
    cjson.cJSON_AddNumberToObject(capabilities, "textDocumentSync", 1);
    cjson.cJSON_AddBoolToObject(capabilities, "hoverProvider", 0);
    cjson.cJSON_AddBoolToObject(capabilities, "definitionProvider", 1);
    cjson.cJSON_AddBoolToObject(capabilities, "documentSymbolProvider", 1);



    // disable for now
    //auto semanticTokensProvider = cjson.cJSON_AddObjectToObject(capabilities, "semanticTokensProvider");
    //cjson.cJSON_AddBoolToObject(semanticTokensProvider, "full", 1);
    //cjson.cJSON_AddBoolToObject(semanticTokensProvider, "range", 1);

    //auto legend = cjson.cJSON_AddObjectToObject(semanticTokensProvider, "legend");
    //const(char*)[27] tok_types = [
    //    "namespace",       // 0
    //    "type",            // 1
    //    "class",           // 2
    //    "enum",            // 3
    //    "interface",       // 4
    //    "struct",          // 5
    //    "typeParameter",   // 6
    //    "parameter",       // 7
    //    "variable",        // 8
    //    "property",        // 9
    //    "enumMember",      // 10
    //    "event",           // 11
    //    "function",        // 12
    //    "method",          // 13
    //    "macro",           // 14
    //    "keyword",         // 15
    //    "modifier",        // 16
    //    "comment",         // 17
    //    "string",          // 18
    //    "number",          // 19
    //    "regexp",          // 20
    //    "operator",        // 21
    //    "decorator",       // 22
    //    /// non standard token type
    //    "errorTag",
    //    /// non standard token type
    //    "builtin",
    //    /// non standard token type
    //    "label",
    //    /// non standard token type
    //    "keywordLiteral",
    //];
    //const(char*)[12] tok_mods = [
    //    "declaration",
    //    "definition",
    //    "readonly",
    //    "static",
    //    "deprecated",
    //    "abstract",
    //    "async",
    //    "modification",
    //    "documentation",
    //    "defaultLibrary",
    //    // non standard token modifiers
    //    "generic",
    //    "_",
    //];
    //auto types = cjson.cJSON_CreateStringArray(tok_types.ptr, tok_types.length);
    //auto mods = cjson.cJSON_CreateStringArray(tok_mods.ptr, tok_mods.length);
    //cjson.cJSON_AddItemToObject(legend, "tokenTypes", types);
    //cjson.cJSON_AddItemToObject(legend, "tokenModifiers", mods);

    auto completion = cjson.cJSON_AddObjectToObject(capabilities, "completionProvider");
    cjson.cJSON_AddBoolToObject(completion, "resolveProvider", 0);

    const(char)*[6] tc = [ ".","=","/","*","+","-"];
    auto triggerCharacters = cjson.cJSON_CreateStringArray(tc.ptr, tc.length);
    cjson.cJSON_AddItemToObject(completion, "triggerCharacters", triggerCharacters);

    auto completionItem = cjson.cJSON_AddObjectToObject(completion, "completionItem");
    cjson.cJSON_AddBoolToObject(completionItem, "labelDetailsSupport", 1);

    auto serverInfo = cjson.cJSON_AddObjectToObject(result, "serverInfo");
    cjson.cJSON_AddStringToObject(serverInfo, "name", "dls");
    cjson.cJSON_AddStringToObject(serverInfo, "version", "0.0.1");

    lsp_send_response(id, result);
}


