add_library(libopenh264 OBJECT EXCLUDE_FROM_ALL)
init_target(libopenh264)
add_library(tg_owt::libopenh264 ALIAS libopenh264)

set(libopenh264_loc ${third_party_loc}/openh264/src)

if (is_x86 OR is_x64)
    target_compile_definitions(libopenh264
    PRIVATE
        X86_ASM
    )
elseif (is_arm AND arm_use_neon)
    target_compile_definitions(libopenh264
    PRIVATE
        HAVE_NEON
    )
elseif (is_aarch64 AND arm_use_neon)
    target_compile_definitions(libopenh264
    PRIVATE
        HAVE_NEON_AARCH64
    )
endif()

nice_target_sources(libopenh264 ${libopenh264_loc}
PRIVATE
    codec/common/inc/WelsList.h
    codec/common/inc/WelsLock.h
    codec/common/inc/WelsTask.h
    codec/common/inc/WelsTaskThread.h
    codec/common/inc/WelsThread.h
    codec/common/inc/WelsThreadLib.h
    codec/common/inc/WelsThreadPool.h
    codec/common/inc/copy_mb.h
    codec/common/inc/cpu.h
    codec/common/inc/cpu_core.h
    codec/common/inc/crt_util_safe_x.h
    codec/common/inc/deblocking_common.h
    codec/common/inc/expand_pic.h
    codec/common/inc/golomb_common.h
    codec/common/inc/intra_pred_common.h
    codec/common/inc/ls_defines.h
    codec/common/inc/macros.h
    codec/common/inc/mc.h
    codec/common/inc/measure_time.h
    codec/common/inc/memory_align.h
    codec/common/inc/sad_common.h
    codec/common/inc/typedefs.h
    codec/common/inc/utils.h
    codec/common/inc/version.h
    codec/common/inc/welsCodecTrace.h
    codec/common/inc/wels_common_defs.h
    codec/common/inc/wels_const_common.h
    codec/common/src/WelsTaskThread.cpp
    codec/common/src/WelsThread.cpp
    codec/common/src/WelsThreadLib.cpp
    codec/common/src/WelsThreadPool.cpp
    codec/common/src/common_tables.cpp
    codec/common/src/copy_mb.cpp
    codec/common/src/cpu.cpp
    codec/common/src/crt_util_safe_x.cpp
    codec/common/src/deblocking_common.cpp
    codec/common/src/expand_pic.cpp
    codec/common/src/intra_pred_common.cpp
    codec/common/src/mc.cpp
    codec/common/src/memory_align.cpp
    codec/common/src/sad_common.cpp
    codec/common/src/utils.cpp
    codec/common/src/welsCodecTrace.cpp
    codec/encoder/core/inc/as264_common.h
    codec/encoder/core/inc/au_set.h
    codec/encoder/core/inc/deblocking.h
    codec/encoder/core/inc/decode_mb_aux.h
    codec/encoder/core/inc/dq_map.h
    codec/encoder/core/inc/encode_mb_aux.h
    codec/encoder/core/inc/encoder.h
    codec/encoder/core/inc/encoder_context.h
    codec/encoder/core/inc/extern.h
    codec/encoder/core/inc/get_intra_predictor.h
    codec/encoder/core/inc/mb_cache.h
    codec/encoder/core/inc/md.h
    codec/encoder/core/inc/mt_defs.h
    codec/encoder/core/inc/mv_pred.h
    codec/encoder/core/inc/nal_encap.h
    codec/encoder/core/inc/param_svc.h
    codec/encoder/core/inc/parameter_sets.h
    codec/encoder/core/inc/paraset_strategy.h
    codec/encoder/core/inc/picture.h
    codec/encoder/core/inc/picture_handle.h
    codec/encoder/core/inc/rc.h
    codec/encoder/core/inc/ref_list_mgr_svc.h
    codec/encoder/core/inc/sample.h
    codec/encoder/core/inc/set_mb_syn_cabac.h
    codec/encoder/core/inc/set_mb_syn_cavlc.h
    codec/encoder/core/inc/slice.h
    codec/encoder/core/inc/slice_multi_threading.h
    codec/encoder/core/inc/stat.h
    codec/encoder/core/inc/svc_base_layer_md.h
    codec/encoder/core/inc/svc_enc_frame.h
    codec/encoder/core/inc/svc_enc_golomb.h
    codec/encoder/core/inc/svc_enc_macroblock.h
    codec/encoder/core/inc/svc_enc_slice_segment.h
    codec/encoder/core/inc/svc_encode_mb.h
    codec/encoder/core/inc/svc_encode_slice.h
    codec/encoder/core/inc/svc_mode_decision.h
    codec/encoder/core/inc/svc_motion_estimate.h
    codec/encoder/core/inc/svc_set_mb_syn.h
    codec/encoder/core/inc/svc_set_mb_syn_cavlc.h
    codec/encoder/core/inc/vlc_encoder.h
    codec/encoder/core/inc/wels_common_basis.h
    codec/encoder/core/inc/wels_const.h
    codec/encoder/core/inc/wels_func_ptr_def.h
    codec/encoder/core/inc/wels_preprocess.h
    codec/encoder/core/inc/wels_task_base.h
    codec/encoder/core/inc/wels_task_encoder.h
    codec/encoder/core/inc/wels_task_management.h
    codec/encoder/core/inc/wels_transpose_matrix.h
    codec/encoder/core/src/au_set.cpp
    codec/encoder/core/src/deblocking.cpp
    codec/encoder/core/src/decode_mb_aux.cpp
    codec/encoder/core/src/encode_mb_aux.cpp
    codec/encoder/core/src/encoder.cpp
    codec/encoder/core/src/encoder_data_tables.cpp
    codec/encoder/core/src/encoder_ext.cpp
    codec/encoder/core/src/get_intra_predictor.cpp
    codec/encoder/core/src/md.cpp
    codec/encoder/core/src/mv_pred.cpp
    codec/encoder/core/src/nal_encap.cpp
    codec/encoder/core/src/paraset_strategy.cpp
    codec/encoder/core/src/picture_handle.cpp
    codec/encoder/core/src/ratectl.cpp
    codec/encoder/core/src/ref_list_mgr_svc.cpp
    codec/encoder/core/src/sample.cpp
    codec/encoder/core/src/set_mb_syn_cabac.cpp
    codec/encoder/core/src/set_mb_syn_cavlc.cpp
    codec/encoder/core/src/slice_multi_threading.cpp
    codec/encoder/core/src/svc_base_layer_md.cpp
    codec/encoder/core/src/svc_enc_slice_segment.cpp
    codec/encoder/core/src/svc_encode_mb.cpp
    codec/encoder/core/src/svc_encode_slice.cpp
    codec/encoder/core/src/svc_mode_decision.cpp
    codec/encoder/core/src/svc_motion_estimate.cpp
    codec/encoder/core/src/svc_set_mb_syn_cabac.cpp
    codec/encoder/core/src/svc_set_mb_syn_cavlc.cpp
    codec/encoder/core/src/wels_preprocess.cpp
    codec/encoder/core/src/wels_task_base.cpp
    codec/encoder/core/src/wels_task_encoder.cpp
    codec/encoder/core/src/wels_task_management.cpp
    codec/encoder/plus/inc/welsEncoderExt.h
    codec/encoder/plus/src/welsEncoderExt.cpp
    codec/processing/interface/IWelsVP.h
    codec/processing/src/adaptivequantization/AdaptiveQuantization.cpp
    codec/processing/src/adaptivequantization/AdaptiveQuantization.h
    codec/processing/src/backgrounddetection/BackgroundDetection.cpp
    codec/processing/src/backgrounddetection/BackgroundDetection.h
    codec/processing/src/common/WelsFrameWork.cpp
    codec/processing/src/common/WelsFrameWork.h
    codec/processing/src/common/WelsFrameWorkEx.cpp
    codec/processing/src/common/common.h
    codec/processing/src/common/memory.cpp
    codec/processing/src/common/memory.h
    codec/processing/src/common/resource.h
    codec/processing/src/common/typedef.h
    codec/processing/src/common/util.h
    codec/processing/src/complexityanalysis/ComplexityAnalysis.cpp
    codec/processing/src/complexityanalysis/ComplexityAnalysis.h
    codec/processing/src/denoise/denoise.cpp
    codec/processing/src/denoise/denoise.h
    codec/processing/src/denoise/denoise_filter.cpp
    codec/processing/src/downsample/downsample.cpp
    codec/processing/src/downsample/downsample.h
    codec/processing/src/downsample/downsamplefuncs.cpp
    codec/processing/src/imagerotate/imagerotate.cpp
    codec/processing/src/imagerotate/imagerotate.h
    codec/processing/src/imagerotate/imagerotatefuncs.cpp
    codec/processing/src/scenechangedetection/SceneChangeDetection.cpp
    codec/processing/src/scenechangedetection/SceneChangeDetection.h
    codec/processing/src/scrolldetection/ScrollDetection.cpp
    codec/processing/src/scrolldetection/ScrollDetection.h
    codec/processing/src/scrolldetection/ScrollDetectionFuncs.cpp
    codec/processing/src/scrolldetection/ScrollDetectionFuncs.h
    codec/processing/src/vaacalc/vaacalcfuncs.cpp
    codec/processing/src/vaacalc/vaacalculation.cpp
    codec/processing/src/vaacalc/vaacalculation.h
)

set(include_directories
    ${libopenh264_loc}
    ${libopenh264_loc}/codec/api/svc
    ${libopenh264_loc}/codec/common/inc
    ${libopenh264_loc}/codec/common/src
    ${libopenh264_loc}/codec/encoder/core/inc
    ${libopenh264_loc}/codec/encoder/core/src
    ${libopenh264_loc}/codec/encoder/plus/inc
    ${libopenh264_loc}/codec/encoder/plus/src
    ${libopenh264_loc}/codec/processing/interface
    ${libopenh264_loc}/codec/processing/src/adaptivequantization
    ${libopenh264_loc}/codec/processing/src/backgrounddetection
    ${libopenh264_loc}/codec/processing/src/common
    ${libopenh264_loc}/codec/processing/src/complexityanalysis
    ${libopenh264_loc}/codec/processing/src/denoise
    ${libopenh264_loc}/codec/processing/src/downsample
    ${libopenh264_loc}/codec/processing/src/imagerotate
    ${libopenh264_loc}/codec/processing/src/scenechangedetection
    ${libopenh264_loc}/codec/processing/src/scrolldetection
    ${libopenh264_loc}/codec/processing/src/vaacalc
)

target_include_directories(libopenh264 PRIVATE ${include_directories})

# Create include-able wels/ directory for public use of the library
set(GEN_INC ${CMAKE_CURRENT_BINARY_DIR}/openh264_include)
add_custom_command(OUTPUT ${GEN_INC}/wels
COMMAND ${CMAKE_COMMAND} -E make_directory ${GEN_INC}/wels
COMMAND ${CMAKE_COMMAND} -E copy
    ${libopenh264_loc}/codec/api/svc/codec_api.h
    ${libopenh264_loc}/codec/api/svc/codec_app_def.h
    ${libopenh264_loc}/codec/api/svc/codec_def.h
    ${libopenh264_loc}/codec/api/svc/codec_ver.h
    ${GEN_INC}/wels
VERBATIM
)
target_sources(libopenh264 PRIVATE ${GEN_INC}/wels)
target_include_directories(libopenh264 PUBLIC $<BUILD_INTERFACE:${GEN_INC}>)

if (is_x86)
    set(yasm_defines X86_32)
else()
    if (WIN32)
        set(yasm_defines WIN64)
    elseif (APPLE)
        set(yasm_defines PREFIX UNIX64 WELS_PRIVATE_EXTERN=:private_extern)
    else()
        set(yasm_defines UNIX64 WELS_PRIVATE_EXTERN=:hidden)
    endif()
endif()

if (is_x86 OR is_x64)

    target_include_directories(libopenh264
    PRIVATE
        ${libopenh264_loc}/codec/common/x86
    )
    set(yasm_sources
        codec/common/x86/cpuid.asm
        codec/common/x86/dct.asm
        codec/common/x86/deblock.asm
        codec/common/x86/expand_picture.asm
        codec/common/x86/intra_pred_com.asm
        codec/common/x86/mb_copy.asm
        codec/common/x86/mc_chroma.asm
        codec/common/x86/mc_luma.asm
        codec/common/x86/satd_sad.asm
        codec/common/x86/vaa.asm
        codec/encoder/core/x86/coeff.asm
        codec/encoder/core/x86/dct.asm
        codec/encoder/core/x86/intra_pred.asm
        codec/encoder/core/x86/matrix_transpose.asm
        codec/encoder/core/x86/memzero.asm
        codec/encoder/core/x86/quant.asm
        codec/encoder/core/x86/sample_sc.asm
        codec/encoder/core/x86/score.asm
        codec/processing/src/x86/denoisefilter.asm
        codec/processing/src/x86/downsample_bilinear.asm
        codec/processing/src/x86/vaa.asm
    )
    if (NOT APPLE)
        list(APPEND yasm_sources
            codec/common/x86/asm_inc.asm
        )
    endif()
    
    target_yasm_sources(libopenh264 ${libopenh264_loc}
    INCLUDE_DIRECTORIES
        ${include_directories}
        ${libopenh264_loc}/codec/common/x86
    DEFINES
        ${yasm_defines}
    SOURCES
        ${yasm_sources}
    )

elseif (is_arm)

    target_include_directories(libopenh264
    PRIVATE
        ${libopenh264_loc}/codec/common/arm
    )
    if (arm_use_neon)
        nice_target_sources(libopenh264 ${libopenh264_loc}
        PRIVATE
            codec/common/arm/copy_mb_neon.S
            codec/common/arm/deblocking_neon.S
            codec/common/arm/expand_picture_neon.S
            codec/common/arm/intra_pred_common_neon.S
            codec/common/arm/mc_neon.S
            codec/processing/src/arm/adaptive_quantization.S
            codec/processing/src/arm/down_sample_neon.S
            codec/processing/src/arm/pixel_sad_neon.S
            codec/processing/src/arm/vaa_calc_neon.S
            codec/encoder/core/arm/intra_pred_neon.S
            codec/encoder/core/arm/intra_pred_sad_3_opt_neon.S
            codec/encoder/core/arm/memory_neon.S
            codec/encoder/core/arm/pixel_neon.S
            codec/encoder/core/arm/reconstruct_neon.S
            codec/encoder/core/arm/svc_motion_estimation.S
        )
    endif()

elseif (is_aarch64)

    target_include_directories(libopenh264
    PRIVATE
        ${libopenh264_loc}/codec/common/arm64
    )
    if (arm_use_neon)
        nice_target_sources(libopenh264 ${libopenh264_loc}
        PRIVATE
            codec/common/arm64/copy_mb_aarch64_neon.S
            codec/common/arm64/deblocking_aarch64_neon.S
            codec/common/arm64/expand_picture_aarch64_neon.S
            codec/common/arm64/intra_pred_common_aarch64_neon.S
            codec/common/arm64/mc_aarch64_neon.S
            codec/processing/src/arm64/adaptive_quantization_aarch64_neon.S
            codec/processing/src/arm64/down_sample_aarch64_neon.S
            codec/processing/src/arm64/pixel_sad_aarch64_neon.S
            codec/processing/src/arm64/vaa_calc_aarch64_neon.S
            codec/encoder/core/arm64/intra_pred_aarch64_neon.S
            codec/encoder/core/arm64/intra_pred_sad_3_opt_aarch64_neon.S
            codec/encoder/core/arm64/memory_aarch64_neon.S
            codec/encoder/core/arm64/pixel_aarch64_neon.S
            codec/encoder/core/arm64/reconstruct_aarch64_neon.S
            codec/encoder/core/arm64/svc_motion_estimation_aarch64_neon.S
        )
    endif()

endif()
