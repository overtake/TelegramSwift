add_library(libabsl OBJECT EXCLUDE_FROM_ALL)
init_target(libabsl)
add_library(tg_owt::libabsl ALIAS libabsl)

set(libabsl_loc ${third_party_loc}/abseil-cpp)

nice_target_sources(libabsl ${libabsl_loc}
PRIVATE
    # absl/base/dynamic_annotations.cc
    # absl/base/internal/cycleclock.cc
    # absl/base/internal/exception_safety_testing.cc
    # absl/base/internal/exponential_biased.cc
    # absl/base/internal/low_level_alloc.cc
    # absl/base/internal/periodic_sampler.cc
    absl/base/internal/raw_logging.cc
    # absl/base/internal/scoped_set_env.cc
    # absl/base/internal/spinlock.cc
    # absl/base/internal/spinlock_wait.cc
    # absl/base/internal/strerror.cc
    # absl/base/internal/sysinfo.cc
    # absl/base/internal/thread_identity.cc
    absl/base/internal/throw_delegate.cc
    # absl/base/internal/unscaledcycleclock.cc
    # absl/base/log_severity.cc
    # absl/container/internal/hash_generator_testing.cc
    # absl/container/internal/hashtablez_sampler.cc
    # absl/container/internal/hashtablez_sampler_force_weak_definition.cc
    # absl/container/internal/raw_hash_set.cc
    # absl/container/internal/test_instance_tracker.cc
    # absl/debugging/failure_signal_handler.cc
    # absl/debugging/internal/address_is_readable.cc
    # absl/debugging/internal/demangle.cc
    # absl/debugging/internal/elf_mem_image.cc
    # absl/debugging/internal/examine_stack.cc
    # absl/debugging/internal/stack_consumption.cc
    # absl/debugging/internal/vdso_support.cc
    # absl/debugging/leak_check.cc
    # absl/debugging/leak_check_disable.cc
    # absl/debugging/stacktrace.cc
    # absl/debugging/symbolize.cc
    # absl/flags/flag.cc
    # absl/flags/flag_test_defs.cc
    # absl/flags/internal/commandlineflag.cc
    # absl/flags/internal/flag.cc
    # absl/flags/internal/program_name.cc
    # absl/flags/internal/registry.cc
    # absl/flags/internal/type_erased.cc
    # absl/flags/internal/usage.cc
    # absl/flags/marshalling.cc
    # absl/flags/parse.cc
    # absl/flags/usage.cc
    # absl/flags/usage_config.cc
    # absl/hash/internal/city.cc
    # absl/hash/internal/hash.cc
    absl/numeric/int128.cc
    # absl/random/discrete_distribution.cc
    # absl/random/gaussian_distribution.cc
    # absl/random/internal/chi_square.cc
    # absl/random/internal/distribution_test_util.cc
    # absl/random/internal/nanobenchmark.cc
    # absl/random/internal/pool_urbg.cc
    # absl/random/internal/randen.cc
    # absl/random/internal/randen_detect.cc
    # absl/random/internal/randen_hwaes.cc
    # absl/random/internal/randen_slow.cc
    # absl/random/internal/seed_material.cc
    # absl/random/seed_gen_exception.cc
    # absl/random/seed_sequences.cc
    # absl/status/status.cc
    # absl/status/status_payload_printer.cc
    absl/strings/ascii.cc
    absl/strings/charconv.cc
    absl/strings/cord.cc
    absl/strings/escaping.cc
    absl/strings/internal/charconv_bigint.cc
    absl/strings/internal/charconv_parse.cc
    absl/strings/internal/escaping.cc
    absl/strings/internal/memutil.cc
    absl/strings/internal/ostringstream.cc
    absl/strings/internal/pow10_helper.cc
    absl/strings/internal/str_format/arg.cc
    absl/strings/internal/str_format/bind.cc
    absl/strings/internal/str_format/extension.cc
    absl/strings/internal/str_format/float_conversion.cc
    absl/strings/internal/str_format/output.cc
    absl/strings/internal/str_format/parser.cc
    absl/strings/internal/utf8.cc
    absl/strings/match.cc
    absl/strings/numbers.cc
    absl/strings/str_cat.cc
    absl/strings/str_replace.cc
    absl/strings/str_split.cc
    absl/strings/string_view.cc
    absl/strings/substitute.cc
    # absl/synchronization/barrier.cc
    # absl/synchronization/blocking_counter.cc
    # absl/synchronization/internal/create_thread_identity.cc
    # absl/synchronization/internal/graphcycles.cc
    # absl/synchronization/internal/per_thread_sem.cc
    # absl/synchronization/internal/waiter.cc
    # absl/synchronization/mutex.cc
    # absl/synchronization/notification.cc
    # absl/time/civil_time.cc
    # absl/time/clock.cc
    # absl/time/duration.cc
    # absl/time/format.cc
    # absl/time/internal/cctz/src/civil_time_detail.cc
    # absl/time/internal/cctz/src/time_zone_fixed.cc
    # absl/time/internal/cctz/src/time_zone_format.cc
    # absl/time/internal/cctz/src/time_zone_if.cc
    # absl/time/internal/cctz/src/time_zone_impl.cc
    # absl/time/internal/cctz/src/time_zone_info.cc
    # absl/time/internal/cctz/src/time_zone_libc.cc
    # absl/time/internal/cctz/src/time_zone_lookup.cc
    # absl/time/internal/cctz/src/time_zone_posix.cc
    # absl/time/internal/cctz/src/zone_info_source.cc
    # absl/time/internal/test_util.cc
    # absl/time/time.cc
    # absl/types/bad_any_cast.cc
    absl/types/bad_optional_access.cc
    absl/types/bad_variant_access.cc
)

target_include_directories(libabsl
PUBLIC
    $<BUILD_INTERFACE:${libabsl_loc}>
    $<INSTALL_INTERFACE:${webrtc_includedir}/third_party/abseil-cpp>
)
