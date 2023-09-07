static const AVCodec * const codec_list[] = {
    &ff_h264_decoder,
    &ff_hevc_decoder,
    &ff_aac_decoder,
    &ff_alac_decoder,
    &ff_flac_decoder,
    &ff_gsm_ms_decoder,
    &ff_mp3_decoder,
    &ff_pcm_s16le_decoder,
    &ff_pcm_s24le_decoder,
    &ff_libopus_decoder,
    &ff_libvpx_vp9_decoder,
    NULL };
