[![CocoaPods](https://img.shields.io/cocoapods/v/PLCrashReporter.svg)](https://cocoapods.org/pods/PLCrashReporter)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager)

# PLCrashReporter

PLCrashReporter is a reliable open source library that provides an in-process live crash reporting framework for use on iOS, macOS and tvOS. The library detects crashes and generates reports to help your investigation and troubleshooting with the information of application, system, process, thread, etc. as well as stack traces.

The easiest way to use PLCrashReporter is by using [AppCenter](https://appcenter.ms). However, if you want to use PLCrashReporter directly, grab the latest release at [releases page](https://github.com/microsoft/plcrashreporter/releases).

## Features

- Uses only supported and public APIs/ABIs for crash reporting.
- The most accurate stack unwinding available, using DWARF and Apple Compact Unwind frame data.
- First released in 2008, and used in hundreds of thousands of apps. PLCrashReporter has seen a tremendous amount of user testing.
- Does not interfere with debugging in lldb/gdb
- Easy to integrate with existing or custom crash reporting services.
- Backtraces for all active threads are provided.
- Provides full register state for the crashed thread.

## Prerequisites

- Xcode 11 or above.
- Minimum supported platforms: iOS 9, macOS 10.9, tvOS 9, Mac Catalyst 13.0.

## Decoding Crash Reports

Crash reports are output as protobuf-encoded messages, and may be decoded using the CrashReporter library or any [Google Protocol Buffers](https://developers.google.com/protocol-buffers/) decoder.

In addition to the in-library decoding support, you may use the included `plcrashutil` binary to convert crash reports to apple's standard iPhone text format. This may be passed to the symbolicate tool.

`plcrashutil convert --format=iphone example_report.plcrash | symbolicatecrash`
Future library releases may include built-in re-usable formatters, for outputting alternative formats directly from the phone.

## Building

### Prerequisites

- A Mac running macOS compliant with Xcode requirements.
- Xcode 11 or above.

Also, next optional tools are used to build additional resources:

- Doxygen to generate the documentation. See [the official Doxygen repository](https://github.com/doxygen/doxygen) for more information or use [Homebrew](https://brew.sh) to install it.
- GraphViz to generate the documentation. See [the official GraphViz website](https://www.graphviz.org/download/) for more information or use [Homebrew](https://brew.sh) to install it.
- `protobuf-c` to convert Protocol Buffer `.proto` files to C descriptor code. See [the official protobuf-c repository](https://github.com/protobuf-c/protobuf-c) for more information or use [Homebrew](https://brew.sh) to install it.

### Building

- Open a new window for your Terminal.
- Go to PLCrashReporter's root folder and run

    ```bash
    xcodebuild -configuration Release -target 'CrashReporter'
    ```

    to create binaries for all platforms.

## Contributing

We are looking forward to your contributions via pull requests.

To contribute to PLCrashReporter, you need the tools mentioned above to build PLCrashReporter for all architectures and `protobuf-c` to convert Protocol Buffer `.proto` files to C descriptor code.

### Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
