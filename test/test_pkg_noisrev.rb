require_relative 'helper'

require_relative '../lib/pkg_noisrev/fbsdpackage.rb'

class TestPkg_noisrev_3101147018 < MiniTest::Unit::TestCase
  def setup
    # this runs every time before test_*
    @cmd = cmd('pkg_noisrev') # get path to the exe & cd to tests directory

    @pkg_dir = 'semis/package'
  end

  def test_origin
    assert_equal(FbsdPackage.origin(@pkg_dir, 'zip-3.0'),
                 ['archivers/zip', 1])
  end
end
