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

    auto def = dcd_hover(buffer.content, pos);
    auto root = cjson.cJSON_CreateObject();

    LWARN("hover: {}", def);

    if (def.length > 0)
    {
        auto value = mem.dupe_add_sentinel(allocator, def);

        auto marked = cjson.cJSON_AddObjectToObject(root, "contents");
        cjson.cJSON_AddStringToObject(marked, "value", value.ptr);
        cjson.cJSON_AddStringToObject(marked, "language", "d");

    }

    lsp_send_response(id, root);
}

