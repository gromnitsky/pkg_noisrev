require_relative 'helper'

require_relative '../lib/pkg_noisrev/fbsdpackage.rb'

class TestFbsdPackage < MiniTest::Unit::TestCase
  def setup
    # this runs every time before test_*
    @cmd = cmd('pkg_noisrev') # get path to the exe & cd to tests directory
  end

  def test_origin
    assert_equal(FbsdPackage.origin(PKG_DIR, 'zip-3.0'),
                 ['archivers/zip', 1])
    assert_raises(Errno::ENOENT) { FbsdPackage.origin(PKG_DIR, 'notexists') }
    assert_equal(FbsdPackage.origin(PKG_DIR, 'xmbdfed-4.7.1_2'),
                 ['x11-fonts/xmbdfed', 3])
    assert_equal(FbsdPackage.origin(PKG_DIR, 'invalid-1.0'),
                 [nil, 0])
  end

  def test_parse_name
    assert_equal(FbsdPackage.parse_name("foo-bar-4.7.1_2"), ['foo-bar', '4.7.1_2'])
    assert_equal(FbsdPackage.parse_name(" "), [' ', '0'])
  end

  def test_dir_collect
    assert_match(assert_raises(RuntimeError) {
                   FbsdPackage.dir_collect "#{PKG_DIR}/zip-3.0"
                 }.message, /no package records in/)

    q = Queue.new
    q.push 'ports'
    q.push 'package'
    r = FbsdPackage.dir_collect PKG_DIR.parent
    2.times { assert_equal(r.pop, q.pop) }
  end

  def test_execution_default
    # 
    r = Trestle.cmd_run("#{@cmd} --pkg-dir #{PKG_DIR} --ports-dir #{PORTS_DIR}")
#    pp r[2].split("\n")
    assert_equal(0, r[0])
    assert_match(/^100% 3\/1\/2 .+\/0$/, r[2])
    assert_match(/^\s*1.0 \?\s*invalid$/, r[2])
    assert_match(/^\s*4.7.1_2 \?\s*xmbdfed$/, r[2])
    assert_match(/^\s*3.0 = 3.0\s*zip$/, r[2])
  end

  def test_execution_likeportmaster
    # bin/pkg_noisrev --pkg-dir test/semis/package --ports-dir test/semis/ports --likeportmaster | egrep '^(\*|[ a-z])' | md5
    r = Trestle.cmd_run("#{@cmd} --pkg-dir #{PKG_DIR} --ports-dir #{PORTS_DIR} --likeportmaster | egrep '^(\\*|[ a-z])' ")
    assert_equal(0, r[0])
    assert_equal(Digest::MD5.hexdigest(r[2]), '621543e28ce56b1bfe9c1ba074451364')
  end

  def test_execution_with_bogus_pkg_dir
    # bin/pkg_noisrev --pkg-dir test/semis --ports-dir test/semis/ports --likeportmaster | egrep '^(\*|[ a-z])' | md5
    r = Trestle.cmd_run("#{@cmd} --pkg-dir #{PKG_DIR.parent} --ports-dir #{PORTS_DIR} --likeportmaster | egrep '^(\\*|[ a-z])' ")
    assert_equal(0, r[0])
    assert_equal(Digest::MD5.hexdigest(r[2]), 'db0f7e1a3d9d9b07f656acd63222339e')
  end

  def test_execution_outofsync
    # bin/pkg_noisrev --pkg-dir test/semis/package --ports-dir test/semis/ports --outofsync | egrep '^(\*|[ a-z])' | md5
    r = Trestle.cmd_run("#{@cmd} --pkg-dir #{PKG_DIR} --ports-dir #{PORTS_DIR} --outofsync | egrep '^(\\*|[ a-z])' ")
    assert_equal(0, r[0])
    assert_equal(Digest::MD5.hexdigest(r[2]), '1245866b4edeba20373357902ca72cb8')
  end
  
end
