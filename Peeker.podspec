Pod::Spec.new do |spec|
  spec.name             = 'Peeker'
  spec.version          = '1.0.0'
  spec.summary          = 'A lightweight iOS Swift library for debugging'
  spec.description      = 'A powerful iOS development tool for inspecting and debugging your app UI components, view hierarchy, and runtime properties'
  spec.homepage         = 'https://github.com/doitduri/Peeker'
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'doitduri' => 'doitduri@gmail.com' }
  spec.source           = { :git => 'https://github.com/doitduri/Peeker.git', :tag => spec.version.to_s }
  
  spec.ios.deployment_target = '13.0'
  spec.swift_version = '5.0'
  spec.source_files = 'Sources/Peeker/**/*.swift'
  spec.frameworks = 'UIKit', 'Foundation'
end