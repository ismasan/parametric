# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'parametric/version'

Gem::Specification.new do |spec|
  spec.name          = "parametric"
  spec.version       = Parametric::VERSION
  spec.authors       = ["Ismael Celis"]
  spec.email         = ["ismaelct@gmail.com"]
  spec.summary       = %q{DSL for declaring allowed parameters with options, regexp patern and default values.}
  spec.description   = %q{Useful for modelling search or form objects, white-listed query parameters and safe parameter defaults.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", '3.4.0'
  spec.add_development_dependency "byebug"
end
