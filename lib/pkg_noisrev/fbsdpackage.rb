require_relative 'threads'
require_relative 'fbsdpackageversion'

module Pkg_noisrev
  class FbsdPackage
    include Enumerable

    # Doesn't contain name
    class OnePackage
      include Comparable
      
      CATEGORY = ['Root (No dependencies, not depended on)',
                  'Trunk (No dependencies, are depended on)',
                  'Branch (Have dependencies, are depended on)',
                  'Leaf (Have dependencies, not depended on)']
      attr_accessor :name, :ver, :origin, :ports_ver, :category
      
      def initialize(name, ver, origin, ports_ver, category)
        @name = name
        @ver = ver
        @origin = origin
        @ports_ver = ports_ver
        @category = category
      end

      # by name
      def <=>(other)
        @name <=> other.name
      end
    end

    attr_reader :db_dir, :ports_dir
    
    def initialize(db_dir, ports_dir)
      @db_dir = db_dir
      @ports_dir = ports_dir
      
      @data = []
      @data_massage = false
      
      @queue = FbsdPackage.dir_collect(@db_dir)
    end

    def each(&block)
      fail "call analyze method first" unless @data_massage
      @data.each{ |i| block.call i }
    end

    # by size
    def <=>(other)
      fail "call analyze method first" unless @data_massage
      @data.size <=> other.size
    end
    
    def analyze(log = nil)
      pkg_total = @queue.size
      STDOUT.puts "#{pkg_total} total: left% processed/okays/failures | thread number: ok/failed\n"
      STDOUT.flush
      
      thread_pool = []
      4.times {|i|
        thread_pool[i] = MyThread.new(i, i) {
          @queue.size.times {
            item = @queue.pop(true) rescue break
            r = FbsdPackage.parse_name item
            category = nil
            begin
              origin, category = FbsdPackage.origin @db_dir, item
              fail "cannot extract the origin for #{name}" unless origin
              
              pver = FbsdPort.ver @ports_dir, origin
              @data << OnePackage.new(r.first, r.last, origin, pver, category)
            rescue
              MyThread.current.stat.failed += 1
              @data << OnePackage.new(r.first, r.last, nil, nil, category)
              log.error "#{$!}" if log
            else
              MyThread.current.stat.ok += 1
            end
          }
        }
      }

      stat = Spectator.new thread_pool, pkg_total, 1
      stat.alarm # print the statistics every 1 second
      
      thread_pool.each(&:join)
      @data_massage = true
      stat.alarm_finish
    end
    
    def self.parse_name(name)
      t = name.split '-'
      return [name, 0] if t.size < 2
      [t[0..-2].join('-'), t.last]
    end
    
    def self.dir_collect(d)
      q = Queue.new
      Dir.glob("#{d}/*").reject {|i| !File.directory?(i) }.map do |i|
        q.push File.basename(i)
      end
      fail "no package records in #{d}" unless q.size > 0
      q
    end

    def self.origin(db_dir, name)
      contents = File.read(db_dir + '/' + name + '/+CONTENTS')
      db_required_by = db_dir + '/' + name + '/' + '+REQUIRED_BY'
      
      category = nil
      origin = nil
      has_dep = contents.match(/^\s*@pkgdep /)
      
      # Set a package category
      #
      # 0--Root (No dependencies, not depended on)
      # 1--Trunk (No dependencies, are depended on)
      # 2--Branch (Have dependencies, are depended on)
      # 3--Leaf (Have dependencies, not depended on)
      if File.size?(db_required_by)
        category = 1
        category = 2 if has_dep
      else
        category = 0
        category = 3 if has_dep
      end
      
      origin = $1 if contents.match(/^\s*@comment\s+ORIGIN:(.+)$/)
      [origin, category]
    end

    def print(mode)
      p = ->(item) {
        cond = '='
        if item.ports_ver
          case FbsdPackageVersion.version_cmp(item.ver, item.ports_ver)
          when -1
            cond = '<'
          when 1
              cond = '>'
          end
        else
          cond = '?'
        end
        puts "%21s %s %-21s %s" % [item.ver, cond, item.ports_ver, item.name]
      }
      
      case mode
      when 'missing'
        @data.reject {|i| i.ports_ver }.sort.each {|idx| p.call idx }
      when 'outofsync'
        @data.reject {|i|
          FbsdPackageVersion.version_cmp(i.ver,
                                         (i.ports_ver ? i.ports_ver : "0")) == 0
        }.sort.each {|idx| p.call idx }
      when 'likeportmaster'
        print_like_portmaster
      else
        @data.sort.each {|idx| p.call(idx) }
      end
    end

    def print_like_portmaster
      root = []
      trunk = []
      branch = []
      leaf = []
      @data.sort.each {|i|
        case i.category
        when 0
          root << i
        when 1
          trunk << i
        when 2
          branch << i
        when 3
          leaf << i
        else
          fail "#{i.name} has no category!"
        end
      }

      outofsync = 0
      p = ->(category, data) {
        return if data.size == 0
        puts "* #{OnePackage::CATEGORY[category]}, #{data.size}"
        data.each {|i|
          puts i.name + '-' + i.ver
          if i.ports_ver
            if FbsdPackageVersion.version_cmp(i.ver, i.ports_ver) != 0
              puts "  => Ports have another version: #{i.ports_ver}"
              outofsync += 1
            end
          else
            puts "  => Not found in ports"
          end
        }
        puts ""
      }

      puts ""
      p.call 0, root
      p.call 1, trunk
      p.call 2, branch
      p.call 3, leaf

      puts "Total #{@data.size}, out of sync #{outofsync}."
    end
  end

  class FbsdPort
    # The last resort method of getting a version number: execute 'make' command
    def self.ver_slow(ports_dir, origin)
      # cannot use just a block for Dir.chdir due to a annoing warning
      # under the another thread
      dirsave = Dir.pwd
      
      Dir.chdir ports_dir + '/' + origin
      r = Trestle.cmd_run('make -V PKGVERSION')
      
      Dir.chdir dirsave
      
      fail "even executing make didn't help #{origin}" if r[0] != 0
      r[2].strip
    end
    
    def self.ver(ports_dir, origin, rlevel = 0)
      fail "recursion level for #{origin} is too high" if rlevel >= 3
      
      makefile = ports_dir + '/' + origin + '/' + 'Makefile'
      ver = {}

      begin
        File.open(makefile) {|f|
          f.each {|line|
            ['MASTERDIR', 'DISTVERSION', 'PORTVERSION', 'PORTREVISION', 'PORTEPOCH'].each {|idx|
              ver[idx] = $1 if line.match(/^\s*#{idx}\s*[?:!]?=\s*(\S+)$/)
            }
          }
        }
      rescue
        fail "(rlevel=#{rlevel}) #{$!}"
      end

      # Recursion! Some ports Makefiles don't contain version definitions
      # but a link to a 'master' port.
      if ver['MASTERDIR']
        rlevel += 1
        master_origin = ver['MASTERDIR'].sub(/\${.CURDIR}/, origin)
        return ver(ports_dir, master_origin, rlevel)
      end


      # check if vars contain sane values
      ok = true
      ver.each {|k,v|
        if v !~ /^[a-zA-Z0-9_,.-]+$/
          ok = false
#          puts makefile
          break
        end
      }
      ver['PORTVERSION'] = ver['DISTVERSION'] = nil if !ok
      
      if ver['PORTVERSION'] || ver['DISTVERSION']
        r = ver['PORTVERSION'] || ver['DISTVERSION']
        r += "_#{ver['PORTREVISION']}" if ver['PORTREVISION']
        r += ",#{ver['PORTEPOCH']}" if ver['PORTEPOCH']
        return r
      end
      
      # try a dumb method
      return FbsdPort.ver_slow(ports_dir, origin) rescue fail "(rlevel=#{rlevel}) #{$!}"
      
      fail "(rlevel=#{rlevel}) cannot extract the version for #{makefile}"
    end
    
  end
end
