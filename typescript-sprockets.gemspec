# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'typescript/sprockets/version'

Gem::Specification.new do |gem|
  gem.name          = 'typescript-sprockets'
  gem.version       = Typescript::Sprockets::VERSION
  gem.platform      = Gem::Platform::RUBY
  gem.authors       = ['Preetpal Sohal', 'FUJI, Goro', 'Klaus Zanders']
  gem.email         = %w(preetpal.sohal@gmail.com)
  gem.description   = %q{Adds Typescript support to Sprockets}
  gem.summary       = %q{Adds Typescript support to Sprockets}
  gem.homepage      = 'https://github.com/preetpalS/typescript-sprockets'

  # gem.add_runtime_dependency 'typescript-node', '>= 1.6.2'
  gem.add_runtime_dependency 'sprockets', '~> 3.7'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.required_ruby_version = '>= 2.0.0'
end
