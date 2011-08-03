require_relative 'threads.rb'

module Pkg_noisrev
  class FbsdPackage

    OnePackage = Struct.new(:ver, :origin, :ports_ver)

    attr_reader :data, :db_dir
    
    def initialize(db_dir, ports_dir)
      @db_dir = db_dir
      @ports_dir = ports_dir
      @data = {}
      @queue = FbsdPackage.dir_collect(@db_dir)
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
            begin
              origin = FbsdPackage.origin @db_dir, item
              pver = FbsdPort.ver @ports_dir, origin
              @data[r.first] = OnePackage.new(r.last, origin, pver)
            rescue
              MyThread.current.stat.failed += 1
              @data[r.first] = OnePackage.new(r.last, nil, nil)
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
    # The last resort method of getting a version number: execute 'make' command
    def self.ver_slow(ports_dir, origin)
      # cannot use just a block for Dir.chdir due to a annoing warning
      # under the another thread
      dirsave = Dir.pwd
      
      Dir.chdir ports_dir + '/' + origin
      r = Trestle.cmd_run('make -V PORTVERSION')
      
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
          while line = f.gets
            ['MASTERDIR', 'DISTVERSION', 'PORTVERSION', 'PORTREVISION', 'PORTEPOCH'].each {|idx|
              ver[idx] = $1 if line.match(/^\s*#{idx}\s*[?:!]?=\s*(\S+)$/)
            }
            
          end
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

# class FbsdPort
#   class Mini < Parslet::Parser
#     root(:lines)

#     rule(:lines) { line.repeat }
#     rule(:line) { spaces >> expression.repeat >> newline }
#     rule(:newline) { hspaces? >> match['\r\n'].repeat(1) }

#     rule(:expression) { ((directive.as(:directive) | conditional.as(:conditional) | assignment.as(:ass)) >> spaces).as(:exp) }
    
#     rule(:spaces) { space.repeat }
#     rule(:space) { line_comment | str(' ') }

#     rule(:hspaces?) { match[' \t'].repeat }
    
#     rule(:line_comment) { hspaces? >> (str('#') >> (newline.absent? >> any).repeat).as(:comment) }
#     rule(:something) { ((newline | line_comment).absent? >> any).repeat }

#     # variable assignments (foo=bar)
#     rule(:assignment) { variable.as(:left) >> hspaces? >> operator.as(:op) >> hspaces? >> something.as(:right) }
#     rule(:variable) { match('[\w]').repeat(1) }
#     rule(:operator) { match['[+:?!]'].maybe >> str('=') }

#     # directives (.include "file")
#     rule(:directive) { str('.') >> (str('include') | str('sinclude') | str('undef') | str('error') | str('warning')).as(:name) >> hspaces? >> something.as(:value) }

#     # conditionals
#     rule(:conditional) { str('.') >> (str('if') | str('ifdef') | str('ifmake') | str('ifnmake')).as(:name) >> hspaces? >> any.as(:body) >> str('\n.endif') }
#   end

#   def self.backslash2line(t)
#     t.gsub!(/\\\s*\n/, " ")
#     t
#   end
  
#   def self.ver(ports_dir, origin, name)
#     code1 = %q(
# c=098
# v=789\
# 101112
# b=  999 
# n=  123   # comment1
    
#   z := "456" # comment 33
# m =

#   # comment2
# .include "foo"
# .if !defined(WITHOUT_HAL)
# LIB_DEPENDS+=	hal.1:${PORTSDIR}/sysutils/hal
# CONFIGURE_ARGS+=	--enable-config-hal=yes
# .else
# CONFIGURE_ARGS+=	--enable-config-hal=no
# .endif

# )
    
#     src = File.read(ports_dir + '/' + origin + '/' + name + '/' + 'Makefile')
#     pp Mini.new.parse_with_debug(FbsdPort.backslash2line(code1))
#     "?"
#   end
# end
