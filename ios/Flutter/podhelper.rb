require 'fileutils'

def flutter_root
  File.expand_path(File.join('..', '..'))
end

def flutter_ios_podfile_setup
  # Ne rien changer ici
end

def install_all_flutter_pods(application_path = nil)
  if application_path.nil?
    application_path = File.dirname(File.realpath(__FILE__))
  end
  install_flutter_engine_pod(application_path)
  install_flutter_plugins(application_path)
end

def install_flutter_engine_pod(application_path)
  engine_dir = File.expand_path(File.join('..', '..', 'bin', 'cache', 'artifacts', 'engine', 'ios'), application_path)
  framework_name = 'Flutter.xcframework'

  unless File.exist?(File.join(engine_dir, framework_name))
    puts "🚨 [Erreur] Flutter framework introuvable !"
    puts "Vérifie que Flutter est bien installé avec : flutter doctor"
    exit 1
  end

  pod 'Flutter', :path => File.join(engine_dir, framework_name)
end

def install_flutter_plugins(application_path)
  plugins_file = File.join(application_path, '..', '.flutter-plugins-dependencies')
  unless File.exist?(plugins_file)
    puts "🚨 Aucun plugin Flutter détecté. Vérifie ton projet !"
    exit 1
  end
  plugins = File.read(plugins_file)
  plugins.split("\n").each do |plugin|
    parts = plugin.split('=')
    name = parts[0].strip
    path = parts[1].strip
    pod name, :path => File.expand_path(path, application_path)
  end
end
