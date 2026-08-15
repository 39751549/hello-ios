# 用 xcodeproj gem 生成 HelloApp.xcodeproj,无需手写 project.pbxproj
require 'xcodeproj'
require 'pathname'

project = Xcodeproj::Project.new('HelloApp.xcodeproj')
target = project.new_target(:application, 'HelloApp', :ios, '14.0')

group = project.main_group.new_group('HelloApp', 'HelloApp')

# 自动收录 HelloApp/ 目录下所有 .swift 文件
swift_files = Dir.glob('HelloApp/*.swift').sort
file_refs = []
swift_files.each do |path|
  rel = Pathname.new(path).relative_path_from(Pathname.new('HelloApp'))
  file_refs << group.new_file(rel.to_s)
end
target.add_file_references(file_refs)

# 添加 Info.plist 文件引用(不参与编译)
info_path = 'HelloApp/Info.plist'
if File.exist?(info_path)
  group.new_file('Info.plist')
end

# 添加 Assets.xcassets(图标资源, 参与编译生成 AppIcon)
xcassets_path = 'HelloApp/Assets.xcassets'
if File.exist?(xcassets_path)
  asset_ref = group.new_file('Assets.xcassets')
  target.add_file_references([asset_ref])
end

settings = {
  'PRODUCT_BUNDLE_IDENTIFIER'                    => 'com.youxi.huanYu',
  'MARKETING_VERSION'                            => '1.0.0',
  'CURRENT_PROJECT_VERSION'                      => '1',
  'GENERATE_INFOPLIST_FILE'                      => 'NO',
  'INFOPLIST_FILE'                               => 'HelloApp/Info.plist',
  'INFOPLIST_KEY_UILaunchScreen_Generation'      => 'YES',
  'INFOPLIST_KEY_UISupportedInterfaceOrientations' => 'UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
  'INFOPLIST_KEY_UIRequiresFullScreen'           => 'YES',
  'INFOPLIST_KEY_UIStatusBarHidden'              => 'YES',
  'ASSETCATALOG_COMPILER_APPICON_NAME'           => 'AppIcon',
  'CODE_SIGN_IDENTITY'                           => '',
  'CODE_SIGNING_REQUIRED'                        => 'NO',
  'CODE_SIGNING_ALLOWED'                         => 'NO',
  'CODE_SIGN_ENTITLEMENTS'                       => '',
  'SWIFT_VERSION'                                => '5.0',
  'TARGETED_DEVICE_FAMILY'                       => '1,2',
  'ENABLE_USER_SCRIPT_SANDBOXING'                => 'NO',
  'SDKROOT'                                      => 'iphoneos',
  'IPHONEOS_DEPLOYMENT_TARGET'                   => '14.0',
  'SWIFT_OBJC_BRIDGING_HEADER'                   => '',
  'OTHER_LDFLAGS'                                => '-weak_framework SceneKit',
}

target.build_configurations.each do |config|
  settings.each { |k, v| config.build_settings[k] = v }
end

# 创建 shared scheme,使 xcodebuild -scheme 可用
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.save_as('HelloApp.xcodeproj', 'HelloApp', true)

project.save
puts "Generated HelloApp.xcodeproj with #{swift_files.length} swift files:"
swift_files.each { |f| puts "  - #{f}" }
