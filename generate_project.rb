# 用 xcodeproj gem 生成 HelloApp.xcodeproj,无需手写 project.pbxproj
require 'xcodeproj'

project = Xcodeproj::Project.new('HelloApp.xcodeproj')
target = project.new_target(:application, 'HelloApp', :ios, '14.0')

group = project.main_group.new_group('HelloApp', 'HelloApp')
app_file = group.new_file('AppDelegate.swift')
vc_file  = group.new_file('ViewController.swift')
target.add_file_references([app_file, vc_file])

settings = {
  'PRODUCT_BUNDLE_IDENTIFIER'                    => 'com.example.helloapp',
  'MARKETING_VERSION'                            => '1.0',
  'CURRENT_PROJECT_VERSION'                      => '1',
  'GENERATE_INFOPLIST_FILE'                      => 'YES',
  'INFOPLIST_KEY_UILaunchScreen_Generation'      => 'YES',
  'INFOPLIST_KEY_UISupportedInterfaceOrientations' => 'UIInterfaceOrientationPortrait',
  'CODE_SIGN_IDENTITY'                           => '',
  'CODE_SIGNING_REQUIRED'                        => 'NO',
  'CODE_SIGNING_ALLOWED'                         => 'NO',
  'CODE_SIGN_ENTITLEMENTS'                       => '',
  'SWIFT_VERSION'                                => '5.0',
  'TARGETED_DEVICE_FAMILY'                       => '1,2',
  'ENABLE_USER_SCRIPT_SANDBOXING'               => 'NO',
  'SDKROOT'                                      => 'iphoneos',
  'IPHONEOS_DEPLOYMENT_TARGET'                   => '14.0'
}

target.build_configurations.each do |config|
  settings.each { |k, v| config.build_settings[k] = v }
end

project.save
puts 'Generated HelloApp.xcodeproj'
