
Gem::Specification.new do |s|
  # Project attributes
  s.name        = "iron-import"
  s.summary     = "CSV, HTML, XLS, and XLSX import automation support"
  s.description = "Simple yet powerful library for importing tabular data from CSV, HTML, XLS and XLSX files, including support for auto-detecting column order, parsing/validating cell data, aggregating errors, etc."

  # Post-install message
  # s.post_install_message = "Thanks for installing!"

  # Additional dependencies
  s.add_dependency "iron-extensions", "~> 1.2", '>= 1.2.1'
  s.add_dependency "iron-dsl", "~> 1.0"

  # Include all gem files that should be packaged
  s.files = Dir[
    "lib/**/*",
    "bin/*",
    "db/*",
    "spec/**/*",
    "LICENSE",
    "*.txt",
    "*.rdoc",
    ".rspec"
  ]
  # Prune out files we don't want to include
  s.files.reject! do |p| 
    ['.tmproj', 'TODO.txt'].detect {|test| p.include?(test)}
  end
  
  # Meta-info
  s.version     = File.read('version.txt').strip
  s.authors     = ["Rob Morris"]
  s.email       = ["rob@irongaze.com"]
  s.homepage    = "http://irongaze.com"
  
  # Boilerplate
  s.platform    = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.executables = Dir["bin/*"].collect {|p| File.basename(p)}
  s.add_development_dependency "rspec", "~> 2.6"
  s.add_development_dependency "roo", "~> 1.13"
  s.add_development_dependency "nokogiri", "~> 1.6"
  s.required_ruby_version = '>= 1.9.2'
  s.license     = 'MIT'
end