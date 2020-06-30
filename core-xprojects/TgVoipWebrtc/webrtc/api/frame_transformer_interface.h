/*
 *  Copyright 2020 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#ifndef API_FRAME_TRANSFORMER_INTERFACE_H_
#define API_FRAME_TRANSFORMER_INTERFACE_H_

#include <memory>
#include <vector>

#include "api/scoped_refptr.h"
#include "api/video/encoded_frame.h"
#include "rtc_base/ref_count.h"

namespace webrtc {

// Owns the frame payload data.
class TransformableFrameInterface {
 public:
  virtual ~TransformableFrameInterface() = default;

  // Returns the frame payload data. The data is valid until the next non-const
  // method call.
  virtual rtc::ArrayView<const uint8_t> GetData() const = 0;

  // Copies |data| into the owned frame payload data.
  virtual void SetData(rtc::ArrayView<const uint8_t> data) = 0;

  virtual uint32_t GetTimestamp() const = 0;
  virtual uint32_t GetSsrc() const = 0;
};

class TransformableVideoFrameInterface : public TransformableFrameInterface {
 public:
  virtual ~TransformableVideoFrameInterface() = default;
  virtual bool IsKeyFrame() const = 0;

  // Returns data needed in the frame transformation logic; for example,
  // when the transformation applied to the frame is encryption/decryption, the
  // additional data holds the serialized generic frame descriptor extension
  // calculated in webrtc::RtpDescriptorAuthentication.
  // TODO(bugs.webrtc.org/11380) remove from interface once
  // webrtc::RtpDescriptorAuthentication is exposed in api/.
  virtual std::vector<uint8_t> GetAdditionalData() const = 0;
};

// Extends the TransformableFrameInterface to expose audio-specific information.
class TransformableAudioFrameInterface : public TransformableFrameInterface {
 public:
  virtual ~TransformableAudioFrameInterface() = default;

  // Exposes the frame header, enabling the interface clients to use the
  // information in the header as needed, for example to compile the list of
  // csrcs.
  virtual const RTPHeader& GetHeader() const = 0;
};

// Objects implement this interface to be notified with the transformed frame.
class TransformedFrameCallback : public rtc::RefCountInterface {
 public:
  // TODO(bugs.webrtc.org/11380) remove after updating downstream dependencies
  // to use new OnTransformedFrame signature.
  virtual void OnTransformedFrame(
      std::unique_ptr<video_coding::EncodedFrame> transformed_frame) {}
  // TODO(bugs.webrtc.org/11380) make pure virtual after updating usage
  // downstream.
  virtual void OnTransformedFrame(
      std::unique_ptr<TransformableFrameInterface> transformed_frame) {}

 protected:
  ~TransformedFrameCallback() override = default;
};

// Transforms encoded frames. The transformed frame is sent in a callback using
// the TransformedFrameCallback interface (see above).
class FrameTransformerInterface : public rtc::RefCountInterface {
 public:
  // Transforms |frame| using the implementing class' processing logic.
  // |additional_data| holds data that is needed in the frame transformation
  // logic, but is not included in |frame|; for example, when the transform
  // function is used for encrypting/decrypting the frame, the additional data
  // holds the serialized generic frame descriptor extension calculated in
  // webrtc::RtpDescriptorAuthentication, needed in the encryption/decryption
  // algorithms.
  // TODO(bugs.webrtc.org/11380) remove after updating downstream dependencies
  // to use new OnTransformedFrame() signature.
  virtual void TransformFrame(std::unique_ptr<video_coding::EncodedFrame> frame,
                              std::vector<uint8_t> additional_data,
                              uint32_t ssrc) {}

  // Transforms |frame| using the implementing class' processing logic.
  // TODO(bugs.webrtc.org/11380) make pure virtual after updating usage
  // downstream.
  virtual void Transform(
      std::unique_ptr<TransformableFrameInterface> transformable_frame) {}

  virtual void RegisterTransformedFrameCallback(
      rtc::scoped_refptr<TransformedFrameCallback>) = 0;
  virtual void UnregisterTransformedFrameCallback() = 0;

 protected:
  ~FrameTransformerInterface() override = default;
};

}  // namespace webrtc

#endif  // API_FRAME_TRANSFORMER_INTERFACE_H_
