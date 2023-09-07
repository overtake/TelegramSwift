add_library(librnnoise OBJECT EXCLUDE_FROM_ALL)
init_target(librnnoise)
add_library(tg_owt::librnnoise ALIAS librnnoise)

set(librnnoise_loc ${third_party_loc}/rnnoise/src)

nice_target_sources(librnnoise ${librnnoise_loc}
PRIVATE
    rnn_activations.h
    rnn_vad_weights.cc
    rnn_vad_weights.h
)

target_include_directories(librnnoise
PRIVATE
    ${webrtc_loc}
)
