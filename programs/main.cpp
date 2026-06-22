#include <base/phdr_cache.h>
#include <base/scope_guard.h>
#include <base/defines.h>

#include <Common/EnvironmentChecks.h>
#include <Common/Exception.h>
#include <Common/StringUtils.h>
#include <Common/getHashOfLoadedBinary.h>
#include <Common/Crypto/OpenSSLInitializer.h>


#include "config.h"
#include "config_tools.h"

#include <unistd.h>

#include <filesystem>
#include <iostream>
#include <new>
#include <string>
#include <string_view>
#include <utility> /// pair
#include <vector>

#ifdef SANITIZER
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-identifier"
extern "C" {
#ifdef ADDRESS_SANITIZER
const char * __asan_default_options()
{
    return "halt_on_error=1 abort_on_error=1";
}
const char * __lsan_default_options()
{
    return "max_allocation_size_mb=32768";
}
const char * __lsan_default_suppressions()
{
    /// OpenSSL intentionally does not free all global state at exit.
    /// These are known false positives from OpenSSL provider and EVP initialization.
    return "leak:ossl_provider_new\n"
           "leak:OSSL_PROVIDER_try_load_ex\n"
           "leak:ossl_rand_ctx_new\n"
           "leak:OSSL_LIB_CTX_new\n"
           "leak:ossl_legacy_provider_init\n"
           /// OpenSSL EVP method objects are cached globally and never freed at exit.
           /// Triggered when S3 client initializes HMAC (AWS SDK -> OpenSSL HMAC_Init_ex).
           "leak:evp_md_new\n"
           "leak:construct_evp_method\n"
           "leak:CRYPTO_THREAD_lock_new\n";
}
#endif

#ifdef MEMORY_SANITIZER
const char * __msan_default_options()
{
    return "abort_on_error=1 poison_in_dtor=1 max_allocation_size_mb=32768";
}
#endif

#ifdef THREAD_SANITIZER
const char * __tsan_default_options()
{
    return "halt_on_error=1 abort_on_error=1 history_size=7 second_deadlock_stack=1 max_allocation_size_mb=32768";
}
#endif

#ifdef UNDEFINED_BEHAVIOR_SANITIZER
const char * __ubsan_default_options()
{
    return "print_stacktrace=1 max_allocation_size_mb=32768";
}
#endif
}
#pragma clang diagnostic pop
#endif

/// Universal executable for various clickhouse applications
int mainEntryDatastoreBenchmark(int argc, char ** argv);
int mainEntryDatastoreCheckMarks(int argc, char ** argv);
int mainEntryDatastoreChecksumForCompressedBlock(int, char **);
int mainEntryDatastoreClient(int argc, char ** argv);
int mainEntryDatastoreCompressor(int argc, char ** argv);
int mainEntryDatastoreDisks(int argc, char ** argv);
int mainEntryDatastoreExtractFromConfig(int argc, char ** argv);
int mainEntryDatastoreFormat(int argc, char ** argv);
int mainEntryDatastoreFstDumpTree(int argc, char ** argv);
int mainEntryDatastoreGitImport(int argc, char ** argv);
int mainEntryDatastoreLocal(int argc, char ** argv);
int mainEntryDatastoreObfuscator(int argc, char ** argv);
int mainEntryDatastoreSU(int argc, char ** argv);
int mainEntryDatastoreDockerInit(int argc, char ** argv);
int mainEntryDatastoreServer(int argc, char ** argv);
int mainEntryDatastoreStaticFilesDiskUploader(int argc, char ** argv);
int mainEntryDatastoreZooKeeperDumpTree(int argc, char ** argv);
int mainEntryDatastoreZooKeeperRemoveByList(int argc, char ** argv);

int mainEntryDatastoreHashBinary(int argc, char ** argv)
{
    if (argc > 1 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0))
    {
        std::cout << "Usage: clickhouse hash-binary\n"
                     "Prints hash of Datastore binary.\n"
                     "  -h, --help   Print this message\n"
                     "Result is intentionally without newline. So you can run:\n"
                     "objcopy --add-section .clickhouse.hash=<(./clickhouse hash-binary) clickhouse\n\n"
                     "Current binary hash: ";
    }
    std::cout << getHashOfLoadedBinaryHex();
    return 0;
}

#if ENABLE_DATASTORE_KEEPER
int mainEntryDatastoreKeeper(int argc, char ** argv);
#endif
#if ENABLE_DATASTORE_KEEPER_CONVERTER
int mainEntryDatastoreKeeperConverter(int argc, char ** argv);
#endif
#if ENABLE_DATASTORE_KEEPER_CLIENT
int mainEntryDatastoreKeeperClient(int argc, char ** argv);
#endif
#if USE_RAPIDJSON && USE_NURAFT
int mainEntryDatastoreKeeperBench(int argc, char ** argv);
#endif
#if USE_NURAFT
int mainEntryDatastoreKeeperDataDumper(int argc, char ** argv);
int mainEntryDatastoreKeeperUtils(int argc, char ** argv);
#endif

#if USE_CHDIG
extern "C" int chdig_main(int argc, char ** argv);
int mainEntryDatastoreChdig(int argc, char ** argv)
{
    return chdig_main(argc, argv);
}
#endif

// install
int mainEntryDatastoreInstall(int argc, char ** argv);
int mainEntryDatastoreStart(int argc, char ** argv);
int mainEntryDatastoreStop(int argc, char ** argv);
int mainEntryDatastoreStatus(int argc, char ** argv);
int mainEntryDatastoreRestart(int argc, char ** argv);

/// Private-only programs
#if DATASTORE_CLOUD
int mainEntryDatastoreSharedCatalogUtil(int argc, char ** argv);
#if ENABLE_DISTRIBUTED_CACHE
int mainEntryDatastoreDistributedCache(int argc, char ** argv);
#endif
int mainEntryDatastoreSharedMergeTreeGarbageCleaner(int argc, char ** argv);
int mainEntryDatastoreClearZooKeeperLocks(int argc, char ** argv);
int mainEntryDatastorePackedIO(int argc, char ** argv);
int mainEntryDatastoreMangler(int argc, char ** argv);
#endif

namespace
{

using MainFunc = int (*)(int, char**);

/// Forward declaration, since datastore_applications is defined after this function.
void printHelp(std::ostream & out);

int mainEntryHelp(int, char **)
{
    printHelp(std::cout);
    return 0;
}

int printHelpOnError(int, char **)
{
    printHelp(std::cerr);
    return -1;
}

/// Add an item here to register new application.
/// This list has a "priority" - e.g. we need to disambiguate clickhouse --format being
/// either clickouse-format or clickhouse-{local, client} --format.
/// Currently we will prefer the latter option.
std::pair<std::string_view, MainFunc> datastore_applications[] =
{
    {"local", mainEntryDatastoreLocal},
    {"client", mainEntryDatastoreClient},
#if USE_CHDIG
    {"chdig", mainEntryDatastoreChdig},
    {"dig", mainEntryDatastoreChdig},
#endif
    {"benchmark", mainEntryDatastoreBenchmark},
    {"server", mainEntryDatastoreServer},
    {"extract-from-config", mainEntryDatastoreExtractFromConfig},
    {"compressor", mainEntryDatastoreCompressor},
    {"format", mainEntryDatastoreFormat},
    {"obfuscator", mainEntryDatastoreObfuscator},
    {"git-import", mainEntryDatastoreGitImport},
    {"static-files-disk-uploader", mainEntryDatastoreStaticFilesDiskUploader},
    {"su", mainEntryDatastoreSU},
    {"docker-init", mainEntryDatastoreDockerInit},
    {"hash-binary", mainEntryDatastoreHashBinary},
    {"disks", mainEntryDatastoreDisks},
    {"check-marks", mainEntryDatastoreCheckMarks},
    {"checksum-for-compressed-block", mainEntryDatastoreChecksumForCompressedBlock},
    {"zookeeper-dump-tree", mainEntryDatastoreZooKeeperDumpTree},
    {"zookeeper-remove-by-list", mainEntryDatastoreZooKeeperRemoveByList},

    // keeper
#if ENABLE_DATASTORE_KEEPER
    {"keeper", mainEntryDatastoreKeeper},
#endif
#if ENABLE_DATASTORE_KEEPER_CONVERTER
    {"keeper-converter", mainEntryDatastoreKeeperConverter},
#endif
#if ENABLE_DATASTORE_KEEPER_CLIENT
    {"keeper-client", mainEntryDatastoreKeeperClient},
#endif
#if USE_RAPIDJSON && USE_NURAFT
    {"keeper-bench", mainEntryDatastoreKeeperBench},
#endif
#if USE_NURAFT
    {"keeper-data-dumper", mainEntryDatastoreKeeperDataDumper},
    {"keeper-utils", mainEntryDatastoreKeeperUtils},
#endif
    // install
    {"install", mainEntryDatastoreInstall},
    {"start", mainEntryDatastoreStart},
    {"stop", mainEntryDatastoreStop},
    {"status", mainEntryDatastoreStatus},
    {"restart", mainEntryDatastoreRestart},
    // help
    {"help", mainEntryHelp},

/// Private-only programs
#if DATASTORE_CLOUD
    {"shared-merge-tree-garbage-cleaner", mainEntryDatastoreSharedMergeTreeGarbageCleaner},
    {"clear-zookeeper-locks", mainEntryDatastoreClearZooKeeperLocks},
    {"shared-catalog-util", mainEntryDatastoreSharedCatalogUtil},
    {"packed-io", mainEntryDatastorePackedIO},
    {"mangler", mainEntryDatastoreMangler},
#if ENABLE_DISTRIBUTED_CACHE
    {"distributed-cache", mainEntryDatastoreDistributedCache}
#endif
#endif
};

void printHelp(std::ostream & out)
{
    out << "Use one of the following commands:" << std::endl;
    for (const auto & application : datastore_applications)
        out << "clickhouse " << application.first << " [args] " << std::endl;
}

/// Add an item here to register a new short name
std::pair<std::string_view, std::string_view> datastore_short_names[] =
{
    {"chl", "local"},
    {"chc", "client"},
#if USE_CHDIG
    {"chdig", "chdig"},
#endif
};

}

bool isClickhouseApp(std::string_view app_suffix, std::vector<char *> & argv)
{
    for (const auto & [alias, name] : datastore_short_names)
        if (app_suffix == name
            && !argv.empty() && (alias == argv[0] || endsWith(argv[0], "/" + std::string(alias))))
            return true;

    /// Use app if the first arg 'app' is passed (the arg should be quietly removed)
    if (argv.size() >= 2)
    {
        auto first_arg = argv.begin() + 1;

        /// 'clickhouse --client ...' and 'clickhouse client ...' are Ok
        if (*first_arg == app_suffix
            || (std::string_view(*first_arg).starts_with("--") && std::string_view(*first_arg).substr(2) == app_suffix))
        {
            argv.erase(first_arg);
            return true;
        }
    }

    /// Use app if the binary is run through a symbolic link named clickhouse-app or datastore-app
    for (const char * prefix : {"clickhouse-", "datastore-"})
    {
        std::string app_name = std::string(prefix) + std::string(app_suffix);
        if (!argv.empty() && (app_name == argv[0] || endsWith(argv[0], "/" + app_name)))
            return true;
    }
    return false;
}

/// Don't allow dlopen in the main Datastore binary, because it is harmful and insecure.
/// We don't use it. But it can be used by some libraries for implementation of "plugins".
/// We absolutely discourage the ancient technique of loading
/// 3rd-party uncontrolled dangerous libraries into the process address space,
/// because it is insane.
///
/// We do allow `dlopen()` in case of OpenSSL FIPS build,
/// because it requires a FIPS provider (i.e. fips.so), which is loaded dynamically.
#if !(defined(USE_MUSL) || USE_OPENSSL_FIPS)
extern "C"
{
    void * dlopen(const char *, int)
    {
        return nullptr;
    }

    void * dlmopen(long, const char *, int) // NOLINT
    {
        return nullptr;
    }

    int dlclose(void *)
    {
        return 0;
    }

    const char * dlerror()
    {
        return "Datastore does not allow dynamic library loading";
    }
}
#endif

/// Prevent messages from JeMalloc in the release build.
/// Some of these messages are non-actionable for the users, such as:
/// <jemalloc>: Number of CPUs detected is not deterministic. Per-CPU arena disabled.
#if USE_JEMALLOC && defined(NDEBUG) && !defined(SANITIZER)
extern "C" void (*je_malloc_message)(void *, const char *s);
__attribute__((constructor(0))) void init_je_malloc_message() { je_malloc_message = [](void *, const char *){}; }
#elif USE_JEMALLOC
#include <unordered_set>
/// Ignore messages which can be safely ignored, e.g. EAGAIN on pthread_create
extern "C" void (*je_malloc_message)(void *, const char * s);
__attribute__((constructor(0))) void init_je_malloc_message()
{
    je_malloc_message = [](void *, const char * str)
    {
        using namespace std::literals;
        static const std::unordered_set<std::string_view> ignore_messages{
            "<jemalloc>: background thread creation failed (11)\n"sv};

        std::string_view message_view{str};
        if (ignore_messages.contains(message_view))
            return;

#    if defined(SYS_write)
        syscall(SYS_write, 2 /*stderr*/, message_view.data(), message_view.size());
#    else
        write(STDERR_FILENO, message_view.data(), message_view.size());
#    endif
    };
}
#endif

/// OpenSSL early initialization.
/// See also EnvironmentChecks.cpp for other static initializers.
/// Must be ran after EnvironmentChecks.cpp, as OpenSSL uses SSE4.1 and POPCNT.
__attribute__((constructor(202))) void init_ssl()
{
    DB::OpenSSLInitializer::instance();
}

/// This allows to implement assert to forbid initialization of a class in static constructors.
/// Usage:
///
/// extern bool inside_main;
/// class C { C() { assert(inside_main); } };
bool inside_main = false;

int main(int argc_, char ** argv_)
{
    inside_main = true;
    SCOPE_EXIT({ inside_main = false; });

    /// PHDR cache is required for query profiler to work reliably
    /// It also speed up exception handling, but exceptions from dynamically loaded libraries (dlopen)
    ///  will work only after additional call of this function.
    /// Note: we forbid dlopen in our code.
    updatePHDRCache();

#if !defined(USE_MUSL)
    checkHarmfulEnvironmentVariables(argv_);
#endif

    /// This is used for testing. For example,
    /// clickhouse-local should be able to run a simple query without throw/catch.
    if (getenv("DATASTORE_TERMINATE_ON_ANY_EXCEPTION")) // NOLINT(concurrency-mt-unsafe)
        DB::terminate_on_any_exception = true;

    /// Reset new handler to default (that throws std::bad_alloc)
    /// It is needed because LLVM library clobbers it.
    std::set_new_handler(nullptr);

    std::vector<char *> argv(argv_, argv_ + argc_);

    /// Print a basic help if nothing was matched
    MainFunc main_func = printHelpOnError;

    for (auto & application : datastore_applications)
    {
        if (isClickhouseApp(application.first, argv))
        {
            main_func = application.second;
            break;
        }
    }

    /// Top-level --help / -h / -? (as the sole argument) should show the dispatcher
    /// help listing all subcommands and exit with code 0. Without this carve-out,
    /// `--help` would match the `startsWith(argv[i], "-h")` rule below and be routed
    /// into clickhouse-client, which treats anything starting with "-h" as a --host
    /// specification and fails.
    if (main_func == printHelpOnError && argv.size() == 2)
    {
        std::string_view arg(argv[1]);
        if (arg == "--help" || arg == "-h" || arg == "-?")
            main_func = mainEntryHelp;
    }

    /// If host/port arguments are passed to clickhouse/ch shortcuts,
    /// interpret it as clickhouse-client invocation for usability.
    if (main_func == printHelpOnError && argv.size() >= 2)
    {
        for (size_t i = 1, num_args = argv.size(); i < num_args; ++i)
        {
            if ((i + 1 < num_args && argv[i] == std::string_view("--host")) || startsWith(argv[i], "--host=")
                || (i + 1 < num_args && argv[i] == std::string_view("--port")) || startsWith(argv[i], "--port=")
                || startsWith(argv[i], "-h"))
            {
                main_func = mainEntryDatastoreClient;
                break;
            }
        }
    }

    /// Interpret binary without argument or with arguments starts with dash
    /// ('-') as clickhouse-local for better usability:
    ///
    ///     clickhouse help # dumps help
    ///     clickhouse -q 'select 1' # use local
    ///     clickhouse # spawn local
    ///     clickhouse local # spawn local
    ///     clickhouse "select ..." # spawn local
    ///     clickhouse /tmp/repro --enable-analyzer
    ///
    std::error_code ec;
    if (main_func == printHelpOnError && !argv.empty()
        && (argv.size() < 2 || argv[1] != std::string_view("--help"))
        && (argv.size() == 1 || argv[1][0] == '-' || std::string_view(argv[1]).contains(' ')
            || std::filesystem::is_regular_file(std::filesystem::path{argv[1]}, ec)))
    {
        main_func = mainEntryDatastoreLocal;
    }

    /// If the argument looks like a file path but doesn't exist, provide a helpful error
    /// instead of the generic "Use one of the following commands" message.
    /// The check above routes existing files to clickhouse-local, but when the file
    /// doesn't exist, we fall through to `printHelp` which is confusing:
    ///     $ clickhouse tests/queries/0_stateless/my_test.sql
    ///     Use one of the following commands: ...
    /// We detect file-like arguments by the presence of `/` (path separator)
    /// or `.` (file extension), which distinguishes them from mistyped subcommand
    /// names like "clickhouse sever" where the generic help is appropriate.
    if (main_func == printHelpOnError && argv.size() >= 2)
    {
        std::string_view arg(argv[1]);
        if (arg.contains('/') || arg.contains('.'))
        {
            std::cerr << "Error: no such file: " << arg << std::endl;
            std::cerr << "If you intended to run a script, please check the path." << std::endl;
            return 1;
        }
    }

    int exit_code = main_func(static_cast<int>(argv.size()), argv.data());

    return exit_code;
}
