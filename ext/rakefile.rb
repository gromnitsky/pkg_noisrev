# Building shared libraries.

module MyDll
  PATH = File.dirname(__FILE__)
  MK = PATH + '/Makefile'
  EXTCONF = PATH + '/extconf.rb'
end

namespace 'mydll' do
  desc "Generate dlls"
  task :default => [MyDll::MK] do |i|
    sh "cd #{MyDll::PATH} && make"
  end

  desc "Clean all crap"
  task :clean => [MyDll::MK] do |i|
    sh "cd #{MyDll::PATH} && make clean"
    rm_rf i.prerequisites
  end
  
  file MyDll::MK => [MyDll::EXTCONF] do |i|
    sh "cd #{MyDll::PATH} && ruby #{i.prerequisites.join(' ')}"
  end
end
