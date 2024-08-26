module dls.dcd;

// public import dcd.server.dll;

extern(C) void dcd_init();
extern(C) void dcd_add_imports(string[] importPaths);
extern(C) void dcd_clear(string[] importPaths);

extern(C) void dcd_on_save(const(char)* filename);
extern(C) AutocompleteResponse dcd_complete(const(char)* filename, const(char)* content, int position);

struct AutocompleteResponse {
    static struct Completion {
        /**
         * The name of the symbol for a completion, for calltips just the function name.
         */
        string identifier;
        /**
         * The kind of the item. Will be char.init for calltips.
         */
        ubyte kind;
        /**
         * Definition for a symbol for a completion including attributes or the arguments for calltips.
         */
        string definition;
        /**
         * The path to the file that contains the symbol.
         */
        string symbolFilePath;
        /**
         * The byte offset at which the symbol is located or symbol location for symbol searches.
         */
        size_t symbolLocation;
        /**
         * Documentation associated with this symbol.
         */
        string documentation;
        // when changing the behavior here, update README.md
        /**
         * For variables, fields, globals, constants: resolved type or empty if unresolved.
         * For functions: resolved return type or empty if unresolved.
         * For constructors: may be struct/class name or empty in any case.
         * Otherwise (probably) empty.
         */
        string typeOf;
    }

    /**
     * The autocompletion type. (Parameters or identifier)
     */
    string completionType;

    /**
     * The path to the file that contains the symbol.
     */
    string symbolFilePath;

    /**
     * The byte offset at which the symbol is located.
     */
    size_t symbolLocation;

    /**
     * The completions
     */
    Completion[] completions;

    /**
     * Import paths that are registered by the server.
     */
    string[] importPaths;

    /**
     * Symbol identifier
     */
    ulong symbolIdentifier;
}


struct DSymbolInfo
{
    string name;
    ubyte kind;
    size_t[2] range;
    DSymbolInfo[] children;
}

extern(C) DSymbolInfo[] dcd_document_symbols(const(char)* content);
extern(C) DSymbolInfo[] dcd_document_symbols_sem(const(char)* content);



struct Location
{
    string path;
    size_t position;
}

extern(C) Location[] dcd_definition(const(char)* content, int position);
extern(C) export string[] dcd_hover(const(char)* content, int position);