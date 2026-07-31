#
# Flutter plugin wrapper around the native GazePointSDK (../ios).
#
Pod::Spec.new do |s|
  s.name             = 'gazepoint_sdk'
  s.version          = '2.0.0'
  s.summary          = 'Flutter plugin for GazePoint SDK'
  s.description      = <<-DESC
    Cross-platform Flutter plugin wrapping the native GazePoint SDKs.
  DESC
  s.homepage         = 'https://github.com/Tareq-Ghassan/FaceDetection-GazePoint'
  s.license          = { :type => 'MIT' }
  s.author           = { 'GazePoint' => 'support@gazepoint.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'GazePointSDK'
  s.platform = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
