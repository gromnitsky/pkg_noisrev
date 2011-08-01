require_relative 'helper'

class TestPkg_noisrev_3101147018 < MiniTest::Unit::TestCase
  def setup
    # this runs every time before test_*
    @cmd = cmd('pkg_noisrev') # get path to the exe & cd to tests directory
  end

  def test_foobar
    fail "\u0430\u0439\u043D\u044D\u043D\u044D".encode(Encoding.default_external, 'UTF-8')
  end
end
