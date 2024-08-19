module dcd.server.dll;

import std.experimental.logger: warning;
import std.string: fromStringz;

import core.runtime;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;
import core.stdc.stdarg;

import dcd.common.messages;
import dcd.server.autocomplete;

import dsymbol.symbol;
import dsymbol.modulecache;

__gshared:

ModuleCache cache;

extern(C) export void dcd_init()
{
    rt_init();
}

extern(C) export void dcd_add_imports(string[] importPaths)
{
    string[] cloned;
    cloned.length = importPaths.length;
    for(int i = 0; i < importPaths.length; i++)
    {
        cloned[i] = importPaths[i].idup;

        warning("adding import: ", cloned[i]);
    }
    cache.addImportPaths(cloned);
}

extern(C) export void dcd_clear()
{
    cache.clear();
}

extern(C) export AutocompleteResponse dcd_complete(const(char)* content, int position)
{
    AutocompleteRequest request;
    request.fileName = "stdin";
    request.cursorPosition = position;
    request.kind |= RequestKind.autocomplete;
    request.sourceCode = cast(ubyte[]) fromStringz(content);

    auto ret = complete(request, cache);
    return ret;
}

struct DSymbolInfo
{
    string name;
    ubyte kind;
    size_t[2] range;
    DSymbolInfo[] children;
}

extern(C) export DSymbolInfo[] dcd_document_symbols(const(char)* content)
{
    import containers.ttree : TTree;
    import containers.hashset;
    import dcd.server.autocomplete.util;

    import dparse.lexer;
    import dparse.rollback_allocator;

    import dsymbol.builtin.names;
    import dsymbol.builtin.symbols;
    import dsymbol.conversion;
    import dsymbol.modulecache;
    import dsymbol.scope_;
    import dsymbol.string_interning;
    import dsymbol.symbol;
    //import dsymbol.ufcs;
    import dsymbol.utils;

    import dcd.common.constants;
    import dcd.common.messages;

    DSymbolInfo[] ret;

    AutocompleteRequest request;
    request.fileName = "stdin";
    request.cursorPosition = 0;
    request.kind |= RequestKind.autocomplete;
    request.sourceCode = cast(ubyte[]) fromStringz(content);

    if (request.sourceCode == null || request.sourceCode.length == 0) return ret;

    LexerConfig config;
    config.fileName = "";
    auto sc = StringCache(request.sourceCode.length.optimalBucketCount);
    auto tokenArray = getTokensForParser(cast(ubyte[]) request.sourceCode, config, &sc);
    RollbackAllocator rba;
    auto pair = generateAutocompleteTrees(tokenArray, &rba, -1, cache);
    scope(exit) pair.destroy();


    void check(DSymbol* it, ref int p, DSymbolInfo* info)
    {
        //for (int i = 0; i < p; i++)
        //fprintf(stderr, " ");
        //fprintf(stderr, "loc: %ld k: %c sym: %.*s\n", it.location, cast(char) it.kind, it.name.length, it.name.ptr);

        p += 1;

        info.name = it.name;
        info.range[0] = it.location;

        if (it.location_end == 0)
            info.range[1] = it.location + it.name.length;
        else
            info.range[1] = it.location_end;
        info.kind = it.kind;

        foreach(sym; it.opSlice())
        {
            if (sym.symbolFile != "stdin") continue;
            if (
                (sym.kind == CompletionKind.functionName 
                || sym.kind == CompletionKind.enumName
                || sym.kind == CompletionKind.structName
                || sym.kind == CompletionKind.unionName
                ) == false
            )
                continue;

            DSymbolInfo child;
            check(sym, p, &child);
            info.children ~= child;
       }
       p -= 1;
    }

    int pos = 0;
    foreach (symbol; pair.scope_.symbols)
    {
        if (symbol.symbolFile != "stdin") continue;
        DSymbolInfo info;
        check(symbol, pos, &info);
        ret ~= info;
    }

    return ret;
}

extern(C) export DSymbolInfo[] dcd_document_symbols_sem(const(char)* content)
{
    import containers.ttree : TTree;
    import containers.hashset;
    import dcd.server.autocomplete.util;

    import dparse.lexer;
    import dparse.rollback_allocator;

    import dsymbol.builtin.names;
    import dsymbol.builtin.symbols;
    import dsymbol.conversion;
    import dsymbol.modulecache;
    import dsymbol.scope_;
    import dsymbol.string_interning;
    import dsymbol.symbol;
    //import dsymbol.ufcs;
    import dsymbol.utils;

    import dcd.common.constants;
    import dcd.common.messages;

    DSymbolInfo[] ret;

    AutocompleteRequest request;
    request.fileName = "stdin";
    request.cursorPosition = 0;
    request.kind |= RequestKind.autocomplete;
    request.sourceCode = cast(ubyte[]) fromStringz(content);

    LexerConfig config;
    config.fileName = "";
    auto sc = StringCache(request.sourceCode.length.optimalBucketCount);
    auto tokenArray = getTokensForParser(cast(ubyte[]) request.sourceCode, config, &sc);
    RollbackAllocator rba;
    auto pair = generateAutocompleteTrees(tokenArray, &rba, -1, cache);
    scope(exit) pair.destroy();


    size_t e;

    void check(DSymbol* it)
    {
        //for (int i = 0; i < p; i++)
        //fprintf(stderr, " ");
        //fprintf(stderr, "loc: %ld k: %c sym: %.*s\n", it.location, cast(char) it.kind, it.name.length, it.name.ptr);

        if (it.type != null)
        {
            //DSymbolInfo info;
            //info.name = it.type.name;
            //info.range[0] = it.type.location;

            //if (it.type.location_end == 0)
            //    info.range[1] = it.type.location + it.type.name.length;
            //else
            //    info.range[1] = it.type.location_end;
            //info.kind = it.type.kind;
            //ret ~= info;
        }


        DSymbolInfo info;
        info.name = it.name;
        info.range[0] = (it.location > e ? it.location - e : e - it.location );
        
        e = it.location;

        if (it.location_end == 0)
            info.range[1] = it.location + it.name.length;
        else
            info.range[1] = it.location_end;
        info.kind = it.kind;
        ret ~= info;

        foreach(sym; it.opSlice())
        {
            if (sym.symbolFile != "stdin") continue;
            
            check(sym);
       }
    }

    foreach (symbol; pair.scope_.symbols)
    {
        if (symbol.symbolFile != "stdin") continue;
        check(symbol);
    }

    return ret;
}

struct Location
{
    string path;
    size_t position;
}

extern(C) export Location[] dcd_definition(const(char)* content, int position)
{
    import containers.ttree : TTree;
    import containers.hashset;
    import dcd.server.autocomplete.util;

    import dparse.lexer;
    import dparse.rollback_allocator;

    import dsymbol.builtin.names;
    import dsymbol.builtin.symbols;
    import dsymbol.conversion;
    import dsymbol.modulecache;
    import dsymbol.scope_;
    import dsymbol.string_interning;
    import dsymbol.symbol;
    import dsymbol.ufcs;
    import dsymbol.utils;

    import dcd.common.constants;
    import dcd.common.messages;

    AutocompleteRequest request;
    request.fileName = "stdin";
    request.cursorPosition = position;
    request.kind |= RequestKind.autocomplete;
    request.sourceCode = cast(ubyte[]) fromStringz(content);

    RollbackAllocator rba;
    auto sc = StringCache(request.sourceCode.length.optimalBucketCount);
    SymbolStuff stuff = getSymbolsForCompletion(request, CompletionType.location, &rba, sc, cache);
    scope(exit) stuff.destroy();

    Location[] ret;
    if (stuff.symbols.length > 0)
    {
        foreach(sym; stuff.symbols)
        {
            //fprintf(stderr, "found: %.*s  at: %.*s -> %lu\n", sym.name.length, sym.name.ptr, sym.symbolFile.length, sym.symbolFile.ptr, sym.location);
            ret ~= Location(sym.symbolFile, sym.location);
        }
    }
    return ret;
}


string from_kind(CompletionKind kind)
{
    switch (kind)
    {
        case CompletionKind.structName: return "struct";
        case CompletionKind.className: return "class";
        case CompletionKind.interfaceName: return "interface";
        case CompletionKind.enumName: return "enum";
        case CompletionKind.unionName: return "union";
        case CompletionKind.aliasName: return "alias";
        default: return "";
    }
}

extern(C) export string[] dcd_hover(const(char)* content, int position)
{
    import containers.ttree : TTree;
    import containers.hashset;
    import dcd.server.autocomplete.util;

    import dparse.lexer;
    import dparse.rollback_allocator;

    import dsymbol.builtin.names;
    import dsymbol.builtin.symbols;
    import dsymbol.conversion;
    import dsymbol.modulecache;
    import dsymbol.scope_;
    import dsymbol.string_interning;
    import dsymbol.symbol;
    import dsymbol.ufcs;
    import dsymbol.utils;

    import dcd.common.constants;
    import dcd.common.messages;

    AutocompleteRequest request;
    request.fileName = "stdin";
    request.cursorPosition = position;
    request.kind |= RequestKind.autocomplete;
    request.sourceCode = cast(ubyte[]) fromStringz(content);

    RollbackAllocator rba;
    auto sc = StringCache(request.sourceCode.length.optimalBucketCount);
    SymbolStuff stuff = getSymbolsForCompletion(request, CompletionType.location, &rba, sc, cache);
    scope(exit) stuff.destroy();

    string[] ret;
    if (stuff.symbols.length > 0)
    {
        foreach(i, sym; stuff.symbols)
        {
            warning("found: ", sym.name, " k:", sym.kind,"  at: ",sym.symbolFile," -> ", sym.location,"\n    ct: ", sym.callTip,"\n");
            if (sym.type)
                warning("  type: ", sym.type.name, " k:", sym.type.kind,"  at: ",sym.type.symbolFile," -> ", sym.type.location,"\n    ct: ", sym.type.callTip,"\n");

            string value;
            if (sym.callTip.length > 0)
            {
                value ~= sym.callTip;
            }
            else
            {
                if (sym.kind == CompletionKind.structName)
                    value ~= "struct";
                else if (sym.kind == CompletionKind.enumName)
                    value ~= "enum";
                else if (sym.kind == CompletionKind.unionName)
                    value ~= "union";
                else if (sym.kind == CompletionKind.className)
                    value ~= "class";
                else if (sym.kind == CompletionKind.interfaceName)
                    value ~= "interface";
                else if (sym.kind == CompletionKind.keyword)
                    value ~= "keyword";
                else if (sym.kind == CompletionKind.variableName)
                {
                    if (sym.type != null)
                    {
                        if (
                            sym.type.kind ==  CompletionKind.structName ||
                            sym.type.kind ==  CompletionKind.className ||
                            sym.type.kind ==  CompletionKind.interfaceName ||
                            sym.type.kind ==  CompletionKind.enumName ||
                            sym.type.kind ==  CompletionKind.unionName ||
                            sym.type.kind ==  CompletionKind.aliasName
                        )
                            value ~= from_kind(sym.type.kind) ~ " ";

                        value ~= sym.type.formatType();
                    }
                }
                else if (sym.kind == CompletionKind.aliasName)
                {
                    value ~= "alias => ";
                    if (sym.type != null)
                    {

                        value ~= sym.type.formatType();
                    }
                }
                else if (sym.kind == CompletionKind.enumMember)
                {
                    // TODO: figure a way to make this useful
                    continue;
                }
            }
            ret ~= value;
        }
    }
    return ret;
}
