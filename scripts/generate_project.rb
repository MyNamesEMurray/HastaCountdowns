require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'Hasta.xcodeproj')
DEPLOYMENT_TARGET = '18.0'
VERSION = '1.0'
BUILD = '1'

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH, false, 77)
project.root_object.development_region = 'en'
project.root_object.known_regions = %w[en Base]
project.root_object.attributes['LastSwiftUpdateCheck'] = '2600'
project.root_object.attributes['LastUpgradeCheck'] = '2600'
project.root_object.attributes['BuildIndependentTargetsInParallel'] = '1'

project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['SDKROOT'] = 'iphoneos'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  config.build_settings['STRING_CATALOG_GENERATE_SYMBOLS'] = 'YES'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  if config.name == 'Debug'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
  else
    config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
    config.build_settings['VALIDATE_PRODUCT'] = 'YES'
  end
end

app = project.new_target(:application, 'Hasta', :ios, DEPLOYMENT_TARGET, nil, :swift)
widget = project.new_target(:app_extension, 'HastaWidgets', :ios, DEPLOYMENT_TARGET, nil, :swift)
tests = project.new_target(:unit_test_bundle, 'HastaTests', :ios, DEPLOYMENT_TARGET, nil, :swift)

[app, widget, tests].each do |target|
  target.frameworks_build_phase.files.each(&:remove_from_project)
end
project.frameworks_group.recursive_children.each(&:remove_from_project)
project.frameworks_group.remove_from_project

common = {
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => '',
  'MARKETING_VERSION' => VERSION,
  'CURRENT_PROJECT_VERSION' => BUILD,
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Hasta',
  'TARGETED_DEVICE_FAMILY' => '1',
  'SWIFT_VERSION' => '5.0',
  'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'SUPPORTS_MACCATALYST' => 'NO',
}

app_settings = common.merge(
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.exaltedpixels.Hasta',
  'INFOPLIST_FILE' => 'App/Info.plist',
  'CODE_SIGN_ENTITLEMENTS' => 'App/Hasta.entitlements',
  'INFOPLIST_KEY_LSApplicationCategoryType' => 'public.app-category.utilities',
  'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
  'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents' => 'YES',
  'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
  'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone' => 'UIInterfaceOrientationPortrait',
  'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption' => 'NO',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES' => 'AppIcon-Midnight AppIcon-Ocean AppIcon-Mint AppIcon-Mono',
  'ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS' => 'NO',
  'ENABLE_PREVIEWS' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks'],
)

widget_settings = common.merge(
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.exaltedpixels.Hasta.widgets',
  'INFOPLIST_FILE' => 'Widgets/Info.plist',
  'CODE_SIGN_ENTITLEMENTS' => 'Widgets/HastaWidgets.entitlements',
  'SKIP_INSTALL' => 'YES',
  'ENABLE_PREVIEWS' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
)

tests_settings = {
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.exaltedpixels.HastaTests',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => '',
  'TARGETED_DEVICE_FAMILY' => '1',
  'SWIFT_VERSION' => '5.0',
  'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
  'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/Hasta.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Hasta',
  'BUNDLE_LOADER' => '$(TEST_HOST)',
}

{ app => app_settings, widget => widget_settings, tests => tests_settings }.each do |target, settings|
  target.build_configurations.each do |config|
    config.build_settings.delete('CODE_SIGN_IDENTITY')
    config.build_settings.delete('CODE_SIGN_IDENTITY[sdk=iphoneos*]')
    config.build_settings.merge!(settings)
  end
end

def add_directory(group, dir, &block)
  Dir.children(dir).sort.each do |child|
    next if child.start_with?('.')
    full = File.join(dir, child)
    if File.directory?(full) && !child.end_with?('.xcassets')
      add_directory(group.new_group(child, child), full, &block)
    else
      ref = group.new_reference(full)
      block.call(ref, full)
    end
  end
end

def membership(target, ref, path)
  case File.extname(path)
  when '.swift'
    target.source_build_phase.add_file_reference(ref, true)
  when '.xcassets', '.xcprivacy', '.xcstrings'
    target.resources_build_phase.add_file_reference(ref, true)
  end
end

main = project.main_group
{ 'App' => [app], 'Shared' => [app, widget], 'Widgets' => [widget], 'Tests' => [tests] }.each do |folder, targets|
  group = main.new_group(folder, folder)
  add_directory(group, File.join(ROOT, folder)) do |ref, path|
    targets.each { |t| membership(t, ref, path) }
  end
end
main.new_reference(File.join(ROOT, 'Hasta.storekit'))

project.main_group.children.delete(project.products_group)
project.main_group.children << project.products_group

embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed_file = embed.add_file_reference(widget.product_reference, true)
embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.add_dependency(widget)
tests.add_dependency(app)

project.root_object.attributes['TargetAttributes'] = {
  app.uuid => { 'CreatedOnToolsVersion' => '26.0' },
  widget.uuid => { 'CreatedOnToolsVersion' => '26.0' },
  tests.uuid => { 'CreatedOnToolsVersion' => '26.0', 'TestTargetID' => app.uuid },
}

project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app, tests, launch_target: true)
scheme.save_as(PROJECT_PATH, 'Hasta', true)

scheme_path = File.join(PROJECT_PATH, 'xcshareddata', 'xcschemes', 'Hasta.xcscheme')
xml = File.read(scheme_path)
storekit = <<~XML.chomp
      <StoreKitConfigurationFileReference
         identifier = "../../Hasta.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
XML
xml = xml.sub('   </LaunchAction>', storekit)
File.write(scheme_path, xml)

puts "Generated #{PROJECT_PATH}"
