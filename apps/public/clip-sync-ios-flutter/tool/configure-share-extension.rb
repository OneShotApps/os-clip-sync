#!/usr/bin/env ruby

require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == 'Runner' }
abort('Runner target was not found.') unless runner

share_group = project.main_group.find_subpath('ShareExtension', true)
share_group.path = 'ShareExtension'
share_group.set_source_tree('<group>')
swift_file = share_group.files.find { |file| file.path == 'ShareViewController.swift' }
swift_file ||= share_group.new_file('ShareViewController.swift')
share_group.new_file('Info.plist') unless share_group.files.any? { |file| file.path == 'Info.plist' }
unless share_group.files.any? { |file| file.path == 'ShareExtension.entitlements' }
  share_group.new_file('ShareExtension.entitlements')
end

share_target = project.targets.find { |target| target.name == 'ShareExtension' }
share_target ||= project.new_target(:app_extension, 'ShareExtension', :ios, '13.0')
share_target.add_file_references([swift_file]) unless share_target.source_build_phase.files_references.include?(swift_file)

share_target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'ShareExtension/ShareExtension.entitlements'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  settings['MARKETING_VERSION'] = '1.0'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.oneshot.clipsync.clipSyncIos.ShareExtension'
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['SKIP_INSTALL'] = 'YES'
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end

runner.build_configurations.each do |configuration|
  configuration.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner.add_dependency(share_target) unless runner.dependencies.any? { |dependency| dependency.target == share_target }

embed_phase = runner.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' }
embed_phase ||= runner.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13'
unless embed_phase.files_references.include?(share_target.product_reference)
  build_file = embed_phase.add_file_reference(share_target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

project.save
puts 'Configured the Clip Sync iOS ShareExtension target.'
