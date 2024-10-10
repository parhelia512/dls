module dls.definition;


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


void lsp_definition(int id, cjson.cJSON * params_json) {
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

    auto locations = dcd_definition(doc.uri, buffer.content, pos);
    auto root = cjson.cJSON_CreateArray();

    foreach(loc; locations)
    {
        auto item = cjson.cJSON_CreateObject();

        Position p;

        // same file
        if (loc.path == "stdin")
        {
            cjson.cJSON_AddStringToObject(item, "uri", doc.uri);
            p = bytesToPosition(it, loc.position);
        }
        // builtin stuff
        else if (loc.path == null || loc.path.length == 0)
        {
            continue;
        }
        // other file
        else
        {

            char[256] newURI = "file://";
            memcpy(newURI.ptr + 7, loc.path.ptr, loc.path.length);
            cjson.cJSON_AddStringToObject(item, "uri", newURI.ptr);

            auto rawURI = mem.dupe_add_sentinel(allocator, loc.path);
            //cjson.cJSON_AddStringToObject(item, "uri", uri.ptr);

            BUFFER bufferp = get_or_open_buffer(rawURI.ptr);
            if (bufferp.content == null) 
            {
                LERRO("buffer empty at: {}", rawURI.ptr);
                continue;
            }

            string itp = cast(string) bufferp.content[0 .. strlen(bufferp.content)];
            p = bytesToPosition(itp, loc.position);
        }

        create_range(item, "range", p, p);

        cjson.cJSON_AddItemToArray(root, item);
    }

    lsp_send_response(id, root);
}

