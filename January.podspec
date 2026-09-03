Pod::Spec.new do |spec|
  spec.name = "January"
  spec.version = "0.1.0-beta.2"
  spec.summary = "The official January SDK for iOS"
  spec.homepage = "https://github.com/January-ai/january-sdk-ios"
  spec.license = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.author = { "January AI" => "oren@january.ai" }
  spec.source = {
    :git => "https://github.com/January-ai/january-sdk-ios.git",
    :tag => spec.version.to_s,
  }
  spec.ios.deployment_target = "15.0"
  spec.swift_version = "5.9"
  spec.source_files = "Sources/JanuarySDK/**/*.swift"
  spec.dependency "JanuaryPartnerTransport", spec.version.to_s
  spec.frameworks = "AVFoundation", "UIKit"
  spec.pod_target_xcconfig = {
    "OTHER_SWIFT_FLAGS" => "$(inherited) -package-name January",
  }
end
