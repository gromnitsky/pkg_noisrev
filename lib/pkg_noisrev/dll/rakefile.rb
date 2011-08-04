# Building shared libraries.

require 'pp'

module MyDll
  PATH = File.dirname(__FILE__)

  # our targets
  OBJ = FileList["#{PATH}/*.c"].sub(/\.c$/, '.o')
  DLL = OBJ.sub /\.o$/, '.so.1'
end

namespace 'mydll' do
  desc "Generate dlls"
  task :default => [MyDll::DLL]

  desc "Clean all crap"
  task :clean do
    rm(MyDll::OBJ, verbose: true, force: true)
    rm(MyDll::DLL, verbose: true, force: true)
  end
  
  desc "Print all staff that _can_ be generated"
  task :print_gen do
    pp MyDll::OBJ
    pp MyDll::DLL
  end

  rule '.o' => ['.c'] do |i|
    sh "cc -Wall -fPIC -c #{i.source} -o #{i.name}"
  end

  # fucking rake, this must be "rule '.so.1' => ['.o']"
  rule(/\.so\.1$/ => [
                      proc {|name| name.sub /\.so\.1$/, '.o' }
                     ]) do |i|
    sh "cc -shared -Wl,-soname,#{File.basename(i.name)} -o #{i.name} #{i.source}"
  end
end
