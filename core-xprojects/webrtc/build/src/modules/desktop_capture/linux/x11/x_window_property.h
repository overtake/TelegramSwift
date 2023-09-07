/*
 *  Copyright (c) 2019 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#ifndef MODULES_DESKTOP_CAPTURE_LINUX_X11_X_WINDOW_PROPERTY_H_
#define MODULES_DESKTOP_CAPTURE_LINUX_X11_X_WINDOW_PROPERTY_H_

#include <X11/X.h>
#include <X11/Xlib.h>

#include <type_traits>
#include <vector>

namespace webrtc {

class XWindowPropertyBase {
 public:
  XWindowPropertyBase(Display* display,
                      Window window,
                      Atom property,
                      int expected_size);
  virtual ~XWindowPropertyBase();

  XWindowPropertyBase(const XWindowPropertyBase&) = delete;
  XWindowPropertyBase& operator=(const XWindowPropertyBase&) = delete;

  // True if we got properly value successfully.
  bool is_valid() const { return is_valid_; }

  // Size and value of the property.
  size_t size() const { return size_; }

 protected:
  unsigned char* data_ = nullptr;

 private:
  bool is_valid_ = false;
  unsigned long size_ = 0;  // NOLINT: type required by XGetWindowProperty
};


// Convenience wrapper for XGetWindowProperty() results.
template <class PropertyType>
class XWindowPropertyGeneric : public XWindowPropertyBase {
 public:
  XWindowPropertyGeneric(Display* display, const Window window, const Atom property)
      : XWindowPropertyBase(display, window, property, sizeof(PropertyType)) {}
  ~XWindowPropertyGeneric() override = default;

  XWindowPropertyGeneric(const XWindowPropertyGeneric&) = delete;
  XWindowPropertyGeneric& operator=(const XWindowPropertyGeneric&) = delete;

  const PropertyType* data() const {
    return reinterpret_cast<PropertyType*>(data_);
  }
  PropertyType* data() { return reinterpret_cast<PropertyType*>(data_); }
};

// See 'XGetWindowProperty' documentation. On 64-bit systems it returns array of 64 bit values:
//
// "If the returned format is 32, the property data will be stored as an array of longs
// (which in a 64-bit application will be 64-bit values that are padded in the upper 4 bytes)."
template <class PropertyType>
class XWindowProperty32On64 : public XWindowPropertyBase {
 public:
  XWindowProperty32On64(Display* display, const Window window, const Atom property)
      : XWindowPropertyBase(display, window, property, sizeof(PropertyType)) {}
  ~XWindowProperty32On64() override = default;

  XWindowProperty32On64(const XWindowProperty32On64&) = delete;
  XWindowProperty32On64& operator=(const XWindowProperty32On64&) = delete;

  const PropertyType* data() const {
    fill_real();
    return real_.data();
  }
  PropertyType* data() {
    fill_real();
    return real_.data();
  }

 private:
  void fill_real() const {
    if (!real_.empty() || !is_valid() || !size()) {
      return;
    }
    real_.resize(size());
    PropertyType *values = reinterpret_cast<PropertyType*>(data_);
    for (PropertyType &value : real_) {
      value = *values;
      values += 2;
    }
  }
  mutable std::vector<PropertyType> real_;
};

template <typename PropertyType>
using XWindowPropertyParent = std::conditional_t<
    sizeof(PropertyType) == 4 && sizeof(void*) == 8,
    XWindowProperty32On64<PropertyType>,
    XWindowPropertyGeneric<PropertyType>>;

template <typename PropertyType>
class XWindowProperty : public XWindowPropertyParent<PropertyType> {
  using Parent = XWindowPropertyParent<PropertyType>;
public:
  using Parent::Parent;
  ~XWindowProperty() override = default;
};

}  // namespace webrtc

#endif  // MODULES_DESKTOP_CAPTURE_LINUX_X11_X_WINDOW_PROPERTY_H_
