module dls.hover;


import rt.dbg;
import mem = rt.memz;
import cjson = cjson;
import rt.str;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;

import dls.main;
import dls.io;
import dls.dcd;

/*
{
    "textDocument": {
        "uri":  "file:///run/media/ryuukk/E0C0C01FC0BFFA3C/dev/kdom/projects/game/app.d"
    },
    "position": {
        "line": 276,
        "character":    16
    }
}
*/


void lsp_hover(int id, cjson.cJSON * params_json) {
    //char* output = cjson.cJSON_Print(params_json);
    //LINFO("{}", output);

    auto allocator = arena.allocator();

    auto doc = lsp_parse_document(params_json);

    if (doc.uri == null) {
        LERRO("doc not found");
        exit(1);
    }

    auto buffer = get_buffer(doc.uri);
    auto it = cast(string) buffer.content[0..strlen(buffer.content)];
    auto pos = positionToBytes(it, doc.line, doc.character);

    auto defs = dcd_hover(buffer.content, pos);


    auto obj = cjson.cJSON_CreateObject();
    auto contents = cjson.cJSON_AddArrayToObject(obj, "contents");

    LWARN("hover: {}", defs.length);

    foreach(def; defs)
    {
        if (def.length == 0)
        {
            auto item = cjson.cJSON_CreateObject();
            cjson.cJSON_AddStringToObject(item, "value", "<empty>");
            cjson.cJSON_AddStringToObject(item, "language", "d");

            cjson.cJSON_AddItemToArray(contents, item);
        }
        else
        {
            auto value = mem.dupe_add_sentinel(allocator, def);
            auto item = cjson.cJSON_CreateObject();
            cjson.cJSON_AddStringToObject(item, "value", value.ptr);
            cjson.cJSON_AddStringToObject(item, "language", "d");

            cjson.cJSON_AddItemToArray(contents, item);
        }

    }

    lsp_send_response(id, obj);
}

