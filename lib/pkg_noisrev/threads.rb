module Pkg_noisrev

  class Spectator
    def initialize(thread_pool, total, sec, stream = STDOUT)
      @thread_pool = thread_pool
      @total = total
      @sec = sec
      
      @stream = stream
      @tty = stream.tty? ? true : false

      @alarm = nil
    end

    def flush_line
      @tty ? @stream.print("\r") : @stream.print("\n")
      @stream.flush
    end

    def draw(thread_pool, total)
      stat = ''
      processed = 0
      okays = 0
      failures = 0
      
      thread_pool.each {|i|
        stat += " | %d: %d/%d" % [i.stat.nthread, i.stat.ok, i.stat.failed]
        okays += i.stat.ok
        failures += i.stat.failed
        processed = okays + failures
      }
      
      # left%/processed/okays/failures
      @stream.print '%d%% %d/%d/%d' % [((processed.to_f/total)*100).round(2), processed, okays, failures] + stat
      flush_line
    end
    
    # Return a tread which will dump a statistics every @sec to a
    # @stream about @thread_pool.
    def alarm
      @alarm = Thread.new(@thread_pool, @total, @sec) { |tp, total, s|
        Thread.current.abort_on_exception = true
        loop {
          draw tp, total
          break if alldone?
          sleep s
        }
      }
    end

    def alarm_finish
      if @alarm
        @alarm.join
        draw @thread_pool, @total
        @stream.print "\n"
      end
    end

    def done_right?
      return false if (@thread_pool.inject(0) {|sum, i| sum+i.stat.ok }) == 0
      true
    end
    
    def alldone?
#      puts ""
#      @thread_pool.each {|i| puts "#{i}=#{i.status}" }
      @thread_pool.each {|i|
        # thread status: false if terminated normally, nil if with exception
        return false if (i.status != nil && i.status != false)
      }
      true
    end
  end

  class MyThread < Thread
    class Stat
      attr_accessor :nthread, :ok, :failed
      
      def initialize(n)
        @nthread = n
        @ok = 0
        @failed = 0
      end

      def to_s
        "%d (o/f): %d/%d" % [@nthread, @ok, @failed]
      end
    end

    attr_accessor :stat

    # n -- thread number
    def initialize(*var, n)
      @stat = Stat.new(n)
      super(*var)
    end
  end

end
