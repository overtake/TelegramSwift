Pod::Spec.new do |s|
  s.name                  = "OCMock"
  s.version               = "3.7.1"
  
  s.summary               = "Mock objects for Objective-C"
  s.description           = <<-DESC
                        OCMock is an Objective-C implementation of mock objects. It provides
                        stubs that return pre-determined values for specific method invocations,
                        dynamic mocks that can be used to verify interaction patterns, and
                        partial mocks to overwrite selected methods of existing objects.
                        DESC
  
  s.homepage              = "http://ocmock.org"
  s.documentation_url     = "http://ocmock.org/reference/"
  s.license               = { :type => "Apache 2.0", :file => "License.txt" }

  s.author                = { "Erik Doernenburg" => "erik@doernenburg.com" }
  s.social_media_url      = "http://twitter.com/erikdoe"
  
  s.source                = { :git => "https://github.com/erikdoe/ocmock.git", :tag => "v3.7.1" }
  s.source_files          = "Source/OCMock/*.{h,m}"

  s.requires_arc          = false
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '4.0'
   
  s.public_header_files   = ["OCMock.h", "OCMockObject.h", "OCMArg.h", "OCMConstraint.h", 
                              "OCMLocation.h", "OCMMacroState.h", "OCMRecorder.h", 
                              "OCMStubRecorder.h", "NSNotificationCenter+OCMAdditions.h", 
                              "OCMFunctions.h", "OCMVerifier.h", "OCMQuantifier.h",
							  "OCMockMacros.h" ]
                              .map { |file| "Source/OCMock/" + file }
  
end
