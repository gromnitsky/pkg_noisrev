# -*-ruby-*-

require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rubygems/package_task'

gem 'rdoc'
require 'rdoc/task'

require_relative 'lib/pkg_noisrev/meta'
include Pkg_noisrev

require_relative 'test/rake_git'

spec = Gem::Specification.new {|i|
  i.name = Meta::NAME
  i.version = `bin/#{i.name} -V`
  i.summary = 'TO DO: fill this variable'
  i.description = i.summary + '.'
  i.author = Meta::AUTHOR
  i.email = Meta::EMAIL
  i.homepage = Meta::HOMEPAGE

  i.platform = Gem::Platform::RUBY
  i.required_ruby_version = '>= 1.9.2'
  i.files = git_ls('.')

  i.executables = FileList['bin/*'].gsub(/^bin\//, '')
  
  i.test_files = FileList['test/test_*.rb']
  
  i.rdoc_options << '-m' << 'doc/README.rdoc'
  i.extra_rdoc_files = FileList['doc/*']

  i.add_dependency('open4', '>= 1.1.0')
  i.add_development_dependency('git', '>= 1.2.5')
}

Gem::PackageTask.new(spec).define

task default: [:repackage]

RDoc::Task.new('html') do |i|
  i.main = 'doc/README.rdoc'
  i.rdoc_files = FileList['doc/*', 'lib/**/*.rb']
#  i.rdoc_files.exclude("lib/**/some-nasty-staff")
end

Rake::TestTask.new do |i|
  i.test_files = FileList['test/test_*.rb']
end