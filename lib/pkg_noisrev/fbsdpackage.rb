require_relative 'threads.rb'

class FbsdPackage

  OnePackage = Struct.new(:ver, :origin, :ports_ver)

  attr_reader :data, :db_dir
  
  def initialize(db_dir, ports_dir)
    @db_dir = db_dir
    @ports_dir = ports_dir
    @data = {}
    @queue = FbsdPackage.dir_collect(@db_dir)
  end

  def analyze
    pkg_total = @queue.size
    STDOUT.puts "#{pkg_total} total: left% processed/okays/failures | thread number: ok/failed\n"
    STDOUT.flush
    
    thread_pool = []
    4.times {|i|
      thread_pool[i] = MyThread.new(i, i) {
        @queue.size.times {
          item = @queue.pop(true) rescue break
          r = FbsdPackage.parse_name item
          begin
            origin = FbsdPackage.origin @db_dir, item
            pver = FbsdPort.ver @ports_dir, origin, r.first
            @data[r.first] = OnePackage.new(r.last, origin, pver)
          rescue
            MyThread.current.stat.failed += 1
            @data[r.first] = OnePackage.new(r.last, nil, nil)
          else
            MyThread.current.stat.ok += 1
          end
        }
      }
    }

    stat = Spectator.new thread_pool, pkg_total, 1
    stat.alarm # print the statistics every 1 second
    
    thread_pool.each(&:join)
    stat.alarm_finish
  end
  
  def self.parse_name(name)
    t = name.split '-'
    [t[0..-2].join('-'), t.last]
  end
  
  def self.dir_collect(d)
    q = Queue.new
    Dir.glob(d +'/*').reject {|i| !File.directory?(i) }.map do |i|
      q.push File.basename(i)
    end
    q
  end

  def self.origin(db_dir, name)
    File.open(db_dir + '/' + name + '/+CONTENTS') {|f|
      while line = f.gets
        break if line.match(/^\s*@comment\s+ORIGIN:(.+)$/)
      end
    }
    fail "cannot extract the origin for #{name}" unless $1
    $1
  end

  # go thought @data and return a list of 4 lists:
  #
  # 0--Root (No dependencies, not depended on)
  # 1--Trunk (No dependencies, are depended on)
  # 2--Branch (Have dependencies, are depended on)
  # 3--Leaf (Have dependencies, not depended on)
  
  # TODO
  def types
    [nil, nil, nil, nil]
  end
end

class FbsdPort
  def self.ver(ports_dir, origin, name)
    "?"
  end
end
