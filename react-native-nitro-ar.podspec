require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-nitro-ar"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  # Swift module name must match nitrogen's iosModuleName
  s.module_name  = "NitroAR"

  s.platforms    = { :ios => '16.0', :visionos => 1.0 }
  s.source       = { :git => "https://github.com/vineyardbovines/react-native-nitro-ar.git", :tag => "#{s.version}" }

  s.source_files = [
    # Implementation (Swift)
    "ios/**/*.{swift}",
    # Autolinking/Registration (Objective-C++)
    "ios/**/*.{m,mm}",
    # Implementation (C++ objects)
    "cpp/**/*.{hpp,cpp}",
  ]

  s.frameworks = [
    'ARKit',
    'SceneKit',
    'UIKit',
  ]

  load 'nitrogen/generated/ios/NitroAR+autolinking.rb'
  add_nitrogen_files(s)

  s.dependency 'React-jsi'
  s.dependency 'React-callinvoker'
  install_modules_dependencies(s)
end
