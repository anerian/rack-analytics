require 'ruby-prof'
require 'ruby-debug'

$reporter = nil
$mutex = Mutex.new
module Rack
  class Reporter
    attr_accessor :logfile
    def initialize(logfile=nil)
      @logfile = logfile
    end
  end
  # Set the profile=process_time query parameter to download a
  # calltree profile of the request.
  #
  # Pass the :printer option to pick a different result format.
  class Analytics
    LOG_DIR = '.'
    LOGFILE_MAX_SIZE = 1024 * 500# in bytes, ie 1 mb
    LOGFILE_MAX_AGE = 3 # in seconds, ie 1 hour

    MODES = %w(
      process_time
      wall_time
      cpu_time
    )

    def initialize(app, options = {})
      $reporter ||= Reporter.new
      @app = app
      @profile_type = :time 
      @write_type = :file
    end

    def call(env)
     case @profile_type 
     when :prof
       profile(env, mode)
     when :time
      start_time = Time.now
      app_response = @app.call(env)
      end_time = Time.now

      time_taken = end_time - start_time
  
      # dup, otherwise we screw up the env hash for rack
      # also merge with an empty new Hash to create a real Hash and not a Mongrel::HttpParams 'hash'
      @rack_env = Hash.new.merge(env.dup)
    
      # a mix of IO and Action::* classes that rails can't to_yaml
      @rack_env.delete('rack.errors')
      @rack_env.delete('rack.input')
      @rack_env.delete('action_controller.rescue.request')
      @rack_env.delete('action_controller.rescue.response')
      @rack_env.delete('rack.session')

      data = {:time_taken => time_taken, :created_at => Time.now.to_i, :rack_env => @rack_env}

      if @write_type == :file
        $mutex.synchronize do
          set_new_logfile unless $reporter.logfile
          filename = $reporter.logfile
          if logfile_needs_rotating?(filename)
            filename = rotate_logfile(filename)
          end
          file_write(filename, data.to_yaml)
        end
      elsif @write_type == :db
        ActiveRecord::Base.connection.insert("insert into log_entries (time_taken, details, created_at) values (#{time_taken}, #{ActiveRecord::Base.connection.quote(@rack_env)}, #{Time.now.to_i})")
      end
      app_response
     else
       @app.call(env)
     end
    end

    def rotate_logfile(filename)
      debug "rotating logfile"
      `mv #{filename} archived.#{filename}`
      set_new_logfile
    end

    def logfile_needs_rotating?(filename)
      # this assumes an analysis.port_number.timestamp.log layout
      created_at = filename.split('.')[2].to_i
      (Time.now.to_i - created_at) > LOGFILE_MAX_AGE or (::File.exists?(filename) and ::File.size(filename) > LOGFILE_MAX_SIZE)
    end
        
    def set_new_logfile
      $reporter.logfile = get_new_logfile_name 
    end

    def get_new_logfile_name
      "analysis.#{@rack_env['SERVER_PORT']}.#{Time.now.to_i}.log"
    end

    def profile(env, mode)
      RubyProf.measure_mode = RubyProf.const_get(mode.upcase)

      rails_response = []
      result = RubyProf.profile do
        rails_response = @app.call(env)
      end

      store_in_filesystem(result, env)

      [200, {'Content-Type' => 'text/html'}, rails_response[2]]
    end

    def file_write(filename, data)
      debug "writing out file #{filename}"
      ::File.open(filename, 'a') {|file| file.write data}
    end

    def store_in_filesystem(result, env)
      filename = "public/analytics.profile.#{timestamp}.txt"
      string = StringIO.new
      RubyProf::FlatPrinter.new(result).print(string, :min_percent => 0.01)
      string.rewind
      file_write(filename, string)

      filename = "public/analytics.rack_env.#{timestamp}.txt"
      file_write(filename, env.to_hash.to_yaml)
    end

    def timestamp
      "%10.6f" % Time.now.to_f
    end

    def debug(text)
      puts text if $DEBUG
    end
  end
end
