# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'levels_beyond/version'

Gem::Specification.new do |spec|
  spec.name          = 'levels_beyond'
  spec.version       = LevelsBeyond::VERSION
  spec.authors       = ['John Whitson']
  spec.email         = ['john.whitson@gmail.com']
  spec.summary       = %q{A library for interacting with Levels Beyond's Products.}
  spec.description   = %q{}
  spec.homepage      = ''
  spec.license       = ''

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.8.7'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
end
