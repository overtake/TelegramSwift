/*
 *  Copyright (c) 2020 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#ifndef MODULES_AUDIO_PROCESSING_TRANSIENT_TRANSIENT_SUPPRESSOR_CREATOR_H_
#define MODULES_AUDIO_PROCESSING_TRANSIENT_TRANSIENT_SUPPRESSOR_CREATOR_H_

#include <memory>

#include "modules/audio_processing/transient/transient_suppressor.h"

namespace webrtc {

// Creates a transient suppressor.
// Will return nullptr if WEBRTC_EXCLUDE_TRANSIENT_SUPPRESSOR is defined.
std::unique_ptr<TransientSuppressor> CreateTransientSuppressor();

}  // namespace webrtc

#endif  // MODULES_AUDIO_PROCESSING_TRANSIENT_TRANSIENT_SUPPRESSOR_CREATOR_H_
