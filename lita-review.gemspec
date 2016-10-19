Gem::Specification.new do |spec|
  spec.name          = 'lita-review'
  spec.version       = '0.1.0'
  spec.authors       = ['hyone']
  spec.email         = ['hyone.development@gmail.com']
  spec.description   = 'choice random reviewrs with equal frequency in everyone'
  spec.summary       = 'choice random reviewrs with equal frequency in everyone'
  spec.homepage      = 'https://hyone-lita-sample.herokuapp.com'
  spec.license       = 'MIT'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '>= 4.7'
  spec.add_runtime_dependency 'octokit', '~> 4.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rspec', '>= 3.0.0'
end
