require_relative 'helper'

require_relative '../lib/pkg_noisrev/fbsdpackage.rb'

class TestFbsdPorts < MiniTest::Unit::TestCase
  def setup
    # this runs every time before test_*
    @cmd = cmd('pkg_noisrev') # get path to the exe & cd to tests directory
  end

  def test_version_dll
    assert_equal(FbsdPackageVersion.version_cmp('1.1', '1.2'), -1)
    assert_equal(FbsdPackageVersion.version_cmp('2.2.2', '2.2.2'), 0)
    assert_equal(FbsdPackageVersion.version_cmp('2.2', '2.1'), 1)
  end

  def test_external_make
    assert_equal(FbsdPort.ver_slow(PORTS_DIR.to_s, "x11-servers/xorg-server"),
                 "1.7.7_1,1")
    assert_raises(Errno::ENOENT) {
      FbsdPort.ver_slow(PORTS_DIR.to_s, "some/dir")
    }
  end

  def test_ver
    assert_equal(FbsdPort.ver(PORTS_DIR.to_s, "x11-servers/xorg-server"),
                 "1.7.7_1,1")
    assert_match(assert_raises(RuntimeError) {
                   FbsdPort.ver(PORTS_DIR.to_s, "some/dir")
                 }.message, /\(rlevel=0\) No such file or directory/)
  end

  def test_moved
    r = FbsdPort.moved PORTS_DIR.to_s
    assert_equal(r.size, 7)
    assert_equal(r['science/bblimage'].date, '2011-07-28')

    out, err = capture_io { FbsdPort.moved 'some/dir' }
    assert_match(/parsing .+\/MOVED failed: No such file/, err)
  end
  
end
