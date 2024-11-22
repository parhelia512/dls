module dcd.server.dll;

import std.experimental.logger: warning;
import std.string: fromStringz;
import std.datetime.systime;
import std.experimental.allocator;
import std.experimental.allocator.building_blocks.allocator_list;
import std.experimental.allocator.building_blocks.region;
import std.experimental.allocator.building_blocks.null_allocator;
import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.gc_allocator : GCAllocator;

import containers.dynamicarray;
import containers.hashset;
import containers.ttree;
import containers.unrolledlist;

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

extern(C) export void dcd_on_save(const(char)* filename, const(char)* content)
{
    import std.algorithm.searching: startsWith;
    auto p = cast(string) fromStringz(filename);
    if (p.startsWith("file://"))
        p = p[7 .. $];
    warning("on_save:", p);
    cache.cacheModule(p);
}

extern(C) export AutocompleteResponse dcd_complete(const(char)* filename, const(char)* content, int position)
{
    import std.algorithm.searching: startsWith;
    auto p = cast(string) fromStringz(filename);
    if (p.startsWith("file://"))
        p = p[7 .. $];

    AutocompleteRequest request;
    request.fileName = p;
    request.cursorPosition = position;
    request.kind |= RequestKind.autocomplete;
    request.sourceCode = cast(ubyte[]) fromStringz(content);


    auto im = istring(p);
    //auto e = cache.getEntryFor(im);
    //if(e) e.modificationTime = SysTime.max;
    cache.cacheModule(im);

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

extern(C) export DSymbolInfo[] dcd_document_symbols(const(char)* filename, const(char)* content)
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
    request.fileName = cast(string) fromStringz(filename);
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


    bool exist(DSymbol* it)
    {
        foreach(ref s; ret)
        {
            if (s.name == it.name && s.kind == it.kind) return true;
        }
        return false;
    }


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
            if (sym.generated) continue;
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
        if (symbol.generated) continue;
        DSymbolInfo info;
        check(symbol, pos, &info);
        ret ~= info;
    }

    return ret;
}

extern(C) export DSymbolInfo[] dcd_document_symbols_sem(const(char)* filename, const(char)* content)
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
    request.fileName = cast(string) fromStringz(filename);
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
            DSymbolInfo info;
            info.name = it.type.name;
            info.range[0] = it.type.location;
            //if (it.type.location_end == 0)
            //    info.range[1] = it.type.location + it.type.name.length;
            //else
            //    info.range[1] = it.type.location_end;
            info.kind = it.type.kind;
            ret ~= info;
        }

        {
            DSymbolInfo info;
            info.name = it.name;
            info.range[0] = it.location;
            //if (it.location_end == 0)
            //    info.range[1] = it.location + it.name.length;
            //else
            //    info.range[1] = it.location_end;

            info.kind = it.kind;
            ret ~= info;
        }



        foreach(sym; it.opSlice())
        {
            if (sym.symbolFile != "stdin") continue;
            if (sym.generated) continue;

            check(sym);
       }
    }

    foreach (symbol; pair.scope_.symbols)
    {
        if (symbol.symbolFile != "stdin") continue;
        if (symbol.generated) continue;
        check(symbol);
    }

    return ret;
}

struct Location
{
    string path;
    size_t position;
}

extern(C) export Location[] dcd_definition(const(char)* filename, const(char)* content, int position)
{
    import std.algorithm;
    import std.array;
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
    request.fileName = cast(string) fromStringz(filename);
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
        foreach(sym; stuff.symbols.uniq)
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

extern(C) export string[] dcd_hover(const(char)* filename, const(char)* content, int position)
{
    import std.algorithm;
    import std.array;
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
    request.fileName = cast(string) fromStringz(filename);
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
        foreach(sym; stuff.symbols.uniq)
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



struct Diagnostic
{
    DiagnosticSeverity severity;
    string message;
    size_t[2] range;
    size_t line;
    size_t column;
    bool use_range;
}

enum DiagnosticSeverity {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,
}


ModuleCache cache_scanner;
extern(C) Diagnostic[] dcd_diagnostic(const(char)* buffer)
{
    Diagnostic[] ret;


    return ret;
}

//extern(C) Diagnostic[] dcd_diagnostic2(const(char)* buffer)
//{
//    import core.stdc.stdio;

//    auto so = stdout;
//    stdout = stderr;
//    scope(exit) stdout = so;

//    import containers.ttree : TTree;
//    import containers.hashset;
//    import dcd.server.autocomplete.util;

//    import dparse.lexer;
//    import dparse.rollback_allocator;
//    import dparse.ast;
//    import dparse.parser;

//    import dsymbol.builtin.names;
//    import dsymbol.builtin.symbols;
//    import dsymbol.conversion;
//    import dsymbol.modulecache;
//    import dsymbol.scope_;
//    import dsymbol.string_interning;
//    import dsymbol.symbol;
//    //import dsymbol.ufcs;
//    import dsymbol.utils;

//    import dcd.common.constants;
//    import dcd.common.messages;

//    import dcd.server.dscanner.analysis.base;
//    import dcd.server.dscanner.analysis.run;
//    import dcd.server.dscanner.analysis.config;
//    import dcd.server.dscanner.utils;


//    auto sourceCode = cast(ubyte[]) fromStringz(buffer);
//    auto sc = StringCache(sourceCode.length.optimalBucketCount);

//    auto staticAnalyze = true;

//    Diagnostic[] ret;


//    try {

//        LexerConfig lc;
//        lc.fileName = "stdin";
//        lc.stringBehavior = StringBehavior.source;
//        // auto tokens = getTokensForParser(sourceCode, lc, &sc);

//        // auto ok = syntaxCheckNoPrint(["stdin"], "pretty", sc, cache_scanner);

//        // dscanner
//        StaticAnalysisConfig config = defaultStaticAnalysisConfig();
//        {

//            RollbackAllocator r;
//            uint errorCount;
//            uint warningCount;
//            const(Token)[] tokens;


//            auto writeMessages = delegate(string fileName, size_t line, size_t column, string message, bool isError){
//                // TODO: proper index and column ranges
//                Diagnostic diag;
//                diag.severity = isError ? DiagnosticSeverity.Error : DiagnosticSeverity.Warning;
//                diag.message = message;
//                diag.line = line;
//                diag.column = column;
//                ret ~= diag;
//            };


//            const Module m = parseModule(lc.fileName, sourceCode, &r, sc, tokens, writeMessages,
//                    null, &errorCount, &warningCount);
//            assert(m);
//            if (errorCount > 0 || (staticAnalyze && warningCount > 0))
//            {
//                // errors???
//            }
//            MessageSet results = analyze(lc.fileName, m, config, cache_scanner, tokens, staticAnalyze);
//            if (results !is null)
//            foreach (result; results[])
//            {
//                // all ~= messageFunctionFormatNoPrint(errorFormat, result, false, code);
//                Diagnostic diag;
//                diag.severity = DiagnosticSeverity.Hint;
//                diag.message = result.diagnostic.message;
//                diag.range[0] = result.diagnostic.startIndex;
//                diag.range[1] = result.diagnostic.endIndex;
//                diag.use_range = true;
//                ret ~= diag;
//                warning(" ddd: ", diag);
//            }

//            warning("diagnostiscs: ", results ? results.length : 0);
//        }
//        //
//    } catch (Exception e) {
//        warning("can't parse this doc");
//    } catch (Error e) {
//        warning("can't parse this doc");
//    }


//    return ret;

//}
