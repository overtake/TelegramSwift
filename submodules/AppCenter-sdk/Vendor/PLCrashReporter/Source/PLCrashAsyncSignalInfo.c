/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#include "PLCrashAsyncSignalInfo.h"

#include <unistd.h>
#include <signal.h>

/**
 * @ingroup plcrash_async_signal_info
 * @{
 */

struct signal_name {
    const int signal;
    const char *name;
};

struct signal_code {
    const int signal;
    const int si_code;
    const char *name;
};

#if __APPLE__
/* Values derived from <sys/signal.h> */
static struct signal_name signal_names[] = {
    { SIGHUP,   "SIGHUP" },
    { SIGINT,   "SIGINT" },
    { SIGQUIT,  "SIGQUIT" },
    { SIGILL,   "SIGILL" },
    { SIGTRAP,  "SIGTRAP" },
    { SIGABRT,  "SIGABRT" },
#ifdef SIGPOLL
    // XXX Is this supported?
    { SIGPOLL,  "SIGPOLL" },
#endif
    { SIGIOT,   "SIGIOT" },
    { SIGEMT,   "SIGEMT" },
    { SIGFPE,   "SIGFPE" },
    { SIGKILL,  "SIGKILL" },
    { SIGBUS,   "SIGBUS" },
    { SIGSEGV,  "SIGSEGV" },
    { SIGSYS,   "SIGSYS" },
    { SIGPIPE,  "SIGPIPE" },
    { SIGALRM,  "SIGALRM" },
    { SIGTERM,  "SIGTERM" },
    { SIGURG,   "SIGURG" },
    { SIGSTOP,  "SIGSTOP" },
    { SIGTSTP,  "SIGTSTP" },
    { SIGCONT,  "SIGCONT" },
    { SIGCHLD,  "SIGCHLD" },
    { SIGTTIN,  "SIGTTIN" },
    { SIGTTOU,  "SIGTTOU" },
    { SIGIO,    "SIGIO" },
    { SIGXCPU,  "SIGXCPU" },
    { SIGXFSZ,  "SIGXFSZ" },
    { SIGVTALRM, "SIGVTALRM" },
    { SIGPROF,  "SIGPROF" },
    { SIGWINCH, "SIGWINCH" },
    { SIGINFO,  "SIGINFO" },
    { SIGUSR1,  "SIGUSR1" },
    { SIGUSR2,  "SIGUSR2" },
    { 0, NULL }
};

static struct signal_code signal_codes[] = {
    /* SIGILL */
    { SIGILL,   ILL_NOOP,       "ILL_NOOP"    },
    { SIGILL,   ILL_ILLOPC,     "ILL_ILLOPC"  },
    { SIGILL,   ILL_ILLTRP,     "ILL_ILLTRP"  },
    { SIGILL,   ILL_PRVOPC,     "ILL_PRVOPC"  },
    { SIGILL,   ILL_ILLOPN,     "ILL_ILLOPN"  },
    { SIGILL,   ILL_ILLADR,     "ILL_ILLADR"  },
    { SIGILL,   ILL_PRVREG,     "ILL_PRVREG"  },
    { SIGILL,   ILL_COPROC,     "ILL_COPROC"  },
    { SIGILL,   ILL_BADSTK,     "ILL_BADSTK"  },

    /* SIGFPE */
    { SIGFPE,   FPE_NOOP,       "FPE_NOOP"    },
    { SIGFPE,   FPE_FLTDIV,     "FPE_FLTDIV"  },
    { SIGFPE,   FPE_FLTOVF,     "FPE_FLTOVF"  },
    { SIGFPE,   FPE_FLTUND,     "FPE_FLTUND"  },
    { SIGFPE,   FPE_FLTRES,     "FPE_FLTRES"  },
    { SIGFPE,   FPE_FLTINV,     "FPE_FLTINV"  },
    { SIGFPE,   FPE_FLTSUB,     "FPE_FLTSUB"  },
    { SIGFPE,   FPE_INTDIV,     "FPE_INTDIV"  },
    { SIGFPE,   FPE_INTOVF,     "FPE_INTOVF"  },

    /* SIGSEGV */
    { SIGSEGV,  SEGV_NOOP,      "SEGV_NOOP"   },
    { SIGSEGV,  SEGV_MAPERR,    "SEGV_MAPERR" },
    { SIGSEGV,  SEGV_ACCERR,    "SEGV_ACCERR" },

    /* SIGBUS */
    { SIGBUS,   BUS_NOOP,       "BUS_NOOP"    },
    { SIGBUS,   BUS_ADRALN,     "BUS_ADRALN"  },
    { SIGBUS,   BUS_ADRERR,     "BUS_ADRERR"  },
    { SIGBUS,   BUS_OBJERR,     "BUS_OBJERR"  },

    /* SIGTRAP */
    { SIGTRAP,  0,              "#0"          },
    { SIGTRAP,  TRAP_BRKPT,     "TRAP_BRKPT"  },
    { SIGTRAP,  TRAP_TRACE,     "TRAP_TRACE"  },

    /* SIGABRT */
    { SIGABRT,  0,              "#0"          },

    { 0, 0, NULL }
};
#else
#error Unsupported Platform
#endif

/**
 * @internal
 *
 * Map a signal code to a signal name, or return NULL if no
 * mapping is available.
 */
const char *plcrash_async_signal_sigcode (int signal, int si_code) {
    for (int i = 0; signal_codes[i].name != NULL; i++) {
        /* Check for match */
        if (signal_codes[i].signal == signal && signal_codes[i].si_code == si_code)
            return signal_codes[i].name;
    }

    /* No match */
    return NULL;
}

/**
 * @internal
 *
 * Map a normalized signal value to a SIGNAME signal string.
 */
const char *plcrash_async_signal_signame (int signal) {
    for (int i = 0; signal_names[i].name != NULL; i++) {
        /* Check for match */
        if (signal_names[i].signal == signal)
            return signal_names[i].name;
    }

    /* No match */
    return NULL;
}

/**
 * @} plcrash_async_signal_info
 */
