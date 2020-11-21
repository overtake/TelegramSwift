Pod::Spec.new do |spec|
  spec.name        = 'PLCrashReporter'
  spec.version     = '1.8.1'
  spec.summary     = 'Reliable, open-source crash reporting for iOS, macOS and tvOS.'
  spec.description = 'PLCrashReporter is a reliable open source library that provides an in-process live crash reporting framework for use on iOS, macOS and tvOS. The library detects crashes and generates reports to help your investigation and troubleshooting with the information of application, system, process, thread, etc. as well as stack traces.'

  spec.homepage    = 'https://github.com/microsoft/plcrashreporter'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.txt' }
  spec.authors     = { 'Microsoft' => 'appcentersdk@microsoft.com' }

  spec.source      = { :http     => "https://github.com/microsoft/plcrashreporter/releases/download/#{spec.version}/PLCrashReporter-#{spec.version}.zip",
                       :flatten  => true }

  spec.ios.deployment_target    = '9.0'
  spec.ios.vendored_frameworks  = "iOS Framework/CrashReporter.framework"

  spec.osx.deployment_target    = '10.9'
  spec.osx.vendored_frameworks  = "Mac OS X Framework/CrashReporter.framework"
  
  spec.tvos.deployment_target   = '9.0'
  spec.tvos.vendored_frameworks = "tvOS Framework/CrashReporter.framework"
end
