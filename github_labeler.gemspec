Gem::Specification.new do |s|
  s.name          = 'github_labeler'
  s.version       = '0.1.0'
  s.date          = '2015-08-21'
  s.summary       = 'Utility for running actions on issue labels in groups of GitHub repositories'
  s.authors       = ['Ivan Zuzak']
  s.email         = 'izuzak@gmail.com'
  s.files         = ['lib/github_labeler.rb']
  s.executables   = ['github_labeler']
  s.homepage      = 'https://github.com/izuzak/github_labeler'
  s.license       = 'MIT'
  s.require_paths = ['lib']

  s.add_runtime_dependency('commander', '~> 4.3')
  s.add_runtime_dependency('octokit', '~> 4.0')

  s.add_development_dependency('rspec', '~> 3.3')
end
