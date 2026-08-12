#
# Flutter iOS plugin. Native gaze math lives under
# gazepoint_sdk/Sources/gazepoint_sdk/GazePointSDK (a snapshot of GazePointSDK-iOS).
#
Pod::Spec.new do |s|
  s.name             = 'gazepoint_sdk'
  s.version          = '3.0.4'
  s.summary          = 'Flutter plugin for GazePoint SDK'
  s.description      = <<-DESC
    Cross-platform Flutter plugin for eye tracking and gaze point detection.
    Includes a snapshot of the native iOS GazePoint SDK sources.
  DESC
  s.homepage         = 'https://github.com/Tareq-Ghassan/GazePointSDK-Flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Tareq Abu Saleh' => 'https://github.com/Tareq-Ghassan' }
  s.source           = { :path => '.' }
  s.source_files     = 'gazepoint_sdk/Sources/gazepoint_sdk/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.frameworks       = 'Vision', 'UIKit', 'AVFoundation', 'CoreMedia'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '6.0'
end
