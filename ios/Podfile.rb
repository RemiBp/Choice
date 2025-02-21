# Charger les fichiers de configuration Flutter
flutter_root = File.expand_path(File.join('..', 'flutter'))

if File.exist?(File.join(flutter_root, 'flutter_export_environment'))
  require File.expand_path(File.join(flutter_root, 'flutter_export_environment'))
end

require File.expand_path(File.join(flutter_root, 'generated.xcconfig')) if File.exist?(File.join(flutter_root, 'generated.xcconfig'))
require File.expand_path(File.join(flutter_root, 'pods_runner')) if File.exist?(File.join(flutter_root, 'pods_runner'))
require File.expand_path(File.join('..', '.symlinks', 'flutter', 'ios_pod_helper.rb')) if File.exist?(File.join('..', '.symlinks', 'flutter', 'ios_pod_helper.rb'))

# Assurer que l'application cible iOS 14.0+
platform :ios, '14.0'

# Utiliser des frameworks dynamiques pour éviter l'erreur du module introuvable
use_frameworks! :linkage => :dynamic
use_modular_headers!

target 'Runner' do
  # Configuration Flutter
  flutter_ios_podfile_setup if defined?(flutter_ios_podfile_setup)
  
  # ✅ Ajout du module `add_2_calendar`
  pod 'add_2_calendar', :path => '../.symlinks/plugins/add_2_calendar/ios'

  # ✅ Installation de tous les pods Flutter
  install_all_flutter_pods(File.dirname(File.realpath(__FILE__))) if defined?(install_all_flutter_pods)

  # ✅ Correction des erreurs liées aux architectures et à Bitcode
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # Désactiver Bitcode car Flutter ne l'utilise pas
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        
        # Exclure l'architecture arm64 pour éviter les erreurs de compilation sur simulateur
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      end
    end
  end
end
