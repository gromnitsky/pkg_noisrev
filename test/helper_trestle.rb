# :erb:
# Various staff for minitest. Include this file into your 'helper.rb'.

require 'fileutils'
include FileUtils

require_relative '../lib/pkg_noisrev/trestle'
include Pkg_noisrev

require 'minitest/autorun'

# Return an absolute path of a _c_.
def cmd(c)
  case File.basename(Dir.pwd)
  when Meta::NAME.downcase
    # test probably is executed from the Rakefile
    Dir.chdir('test')
    STDERR.puts('*** chdir to ' + Dir.pwd)
  when 'test'
    # we are in the test directory, there is nothing special to do
  else
    # tests were invoked by 'gem check -t pkg_noisrev'
    # (for a classic rubygems 1.3.7)
    begin
      Dir.chdir(Trestle.gem_libdir + '/../../test')
    rescue
      raise "running tests from '#{Dir.pwd}' isn't supported: #{$!}"
    end
  end

  File.absolute_path('../bin/' + c)
end

# Don't remove this: falsework/0.2.7/naive/2011-07-17T01:52:43+03:00
