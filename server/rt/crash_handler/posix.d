module rt.crash_handler.posix;

import core.stdc.stdlib: free, exit;
import core.stdc.string: strlen, memcpy;
import core.stdc.stdio: fprintf, stderr, sprintf, fgets, fclose, FILE;
import core.sys.posix.unistd: readlink;
import core.sys.posix.signal: SIGUSR1;
import core.sys.posix.stdio: popen, pclose;
import core.sys.linux.execinfo: backtrace, backtrace_symbols;
import core.sys.linux.dlfcn: dladdr1, Dl_info, RTLD_DL_LINKMAP;
import core.sys.linux.link: link_map;

extern(C) export void rt_register_crash_handler(const(char)* filename)
{
    signal(SIGSEGV, &handler);
    signal(SIGUSR1, &handler);
}

extern (C):
private:

void handler(int sig)
{
    enum MAX_DEPTH = 32;

    string signal_string;
    switch (sig)
    {
    case SIGSEGV:
        signal_string = "SIGSEGV";
        break;
    case SIGFPE:
        signal_string = "SIGFPE";
        break;
    case SIGILL:
        signal_string = "SIGILL";
        break;
    case SIGABRT:
        signal_string = "SIGABRT";
        break;
    default:
        signal_string = "unknown";
        break;
    }

    // fprintf(stderr, "-------------------------------------------------------------------+\r\n");
    // fprintf(stderr, "Received signal '%s' (%d)\r\n", signal_string.ptr, sig);
    // fprintf(stderr, "-------------------------------------------------------------------+\r\n");
    fprintf(stderr, "\r\ncrash: %s\r\n", signal_string.ptr);

    void*[MAX_DEPTH] trace;
    int stack_depth = backtrace(&trace[0], MAX_DEPTH);

    char** strings = backtrace_symbols(&trace[0], stack_depth);

    enum BUF_SIZE = 1024;
    char[BUF_SIZE] syscom = 0;
    char[BUF_SIZE] my_exe = 0;
    char[BUF_SIZE] output = 0;

    readlink("/proc/self/exe", &my_exe[0], BUF_SIZE);

    // fprintf(stderr, "executable: %s\n", &my_exe[0]);
    // fprintf(stderr, "backtrace: %i\n", stack_depth);

    for (auto i = stack_depth-1; i >= 2; --i)
    {
        auto line = strings[i];
        auto len = strlen(line);
        bool insideParenthesis;
        int startParenthesis;
        int endParenthesis;
        for (int j = 0; j < len; j++)
        {
            // ()
            if (!insideParenthesis && line[j] == '(')
            {
                insideParenthesis = true;
                startParenthesis = j + 1;
            }
            else if (insideParenthesis && line[j] == ')')
            {
                insideParenthesis = false;
                endParenthesis = j;
            }
        }
        size_t addr;
        auto lmap = convert_to_vma(cast(size_t) trace[i], &addr);
        FILE* fp;

        sprintf(&syscom[0], "addr2line -e %s %p | ddemangle",
            lmap.l_name[0] != 0 ? lmap.l_name : &my_exe[0],
            cast(void*) addr);
        fp = popen(&syscom[0], "r");

        fgets(&output[0], output.length, fp);
        fclose(fp);

        //fprintf(stderr, "    syscom: %s     %s::%s\n", &syscom[0], &my_exe[0], lmap.l_name);

        auto getLen = strlen(output.ptr);

        char[256] func = 0;
        memcpy(func.ptr, &line[startParenthesis], (endParenthesis - startParenthesis));
        sprintf(&syscom[0], "echo '%s' | ddemangle", func.ptr);
        fp = popen(&syscom[0], "r");

        output[getLen - 1] = ' '; // strip new line
        fgets(&output[getLen], cast(int)(output.length - getLen), fp);
        fclose(fp);

        fprintf(stderr, "    %s", output.ptr);
    }

    fprintf(stderr, "\r\n");
    exit(-1);
}

// https://stackoverflow.com/questions/56046062/linux-addr2line-command-returns-0/63856113#63856113
link_map* convert_to_vma(size_t addr, size_t* converted)
{
    //import rt.dbg;
    Dl_info info;
    link_map* link_map;
    dladdr1(cast(void*) addr, &info, cast(void**)&link_map, RTLD_DL_LINKMAP);

    //LINFO("{}", link_map.l_name);
    *converted = addr - link_map.l_addr;
    return link_map;
    //return addr - link_map.l_addr;
    //return addr - cast(size_t) info.dli_saddr;
}


// this should be volatile
///
alias sig_atomic_t = int;

alias sigfn_t = void function(int);

///
enum SIG_ERR    = cast(sigfn_t) -1;
///
enum SIG_DFL    = cast(sigfn_t) 0;
///
enum SIG_IGN    = cast(sigfn_t) 1;

// standard C signals
///
enum SIGABRT    = 6;  // Abnormal termination
///
enum SIGFPE     = 8;  // Floating-point error
///
enum SIGILL     = 4;  // Illegal hardware instruction
///
enum SIGINT     = 2;  // Terminal interrupt character
///
enum SIGSEGV    = 11; // Invalid memory reference
///
enum SIGTERM    = 15; // Termination



///
sigfn_t signal(int sig, sigfn_t func);
///
int     raise(int sig);
