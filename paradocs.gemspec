# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'paradocs/version'

Gem::Specification.new do |spec|
  spec.name          = "paradocs"
  spec.version       = Paradocs::VERSION
  spec.authors       = ["Ismael Celis", "Maxim Tkachenko"]
  spec.email         = ["ismaelct@gmail.com", "tkachenko.maxim.w@gmail.com"]
  spec.summary       = %q{Flexible DSL for declaring allowed parameters focused on DRY validation and docs generation.}
  spec.description   = %q{A huge add-on for original gem mostly focused on retrieving the more metadata from declared schemas as possible.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", '3.4.0'
  spec.add_development_dependency "pry"
end
