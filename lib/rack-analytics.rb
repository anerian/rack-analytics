puts "required main class here"
require 'ruby-prof'
require 'ruby-debug'

module Rack
  # Set the profile=process_time query parameter to download a
  # calltree profile of the request.
  #
  # Pass the :printer option to pick a different result format.
  class Analytics
    BUFFER_SIZE = 5
    MODES = %w(
      process_time
      wall_time
      cpu_time
    )

    def initialize(app, options = {})
      @app = app
      @profile_type = :time 
      @write_type = :file
      if @write_type == :file
        @analytics_data = []
      end
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
      rack_env = Hash.new.merge(env.dup)
    
      # a mix of IO and Action::* classes that rails can't to_yaml
      rack_env.delete('rack.errors')
      rack_env.delete('rack.input')
      rack_env.delete('action_controller.rescue.request')
      rack_env.delete('action_controller.rescue.response')
      rack_env.delete('rack.session')

      if @write_type == :file
        if should_writeout_data
          file_write("analysis.current.log", @analytics_data.to_yaml)
          @analytics_data = []
        else
          @analytics_data << {:time_taken => time_taken, :created_at => Time.now.to_i, :rack_env => rack_env}
        end
      elsif @write_type == :db
        ActiveRecord::Base.connection.insert("insert into log_entries (time_taken, details, created_at) values (#{time_taken}, #{ActiveRecord::Base.connection.quote(rack_env)}, #{Time.now.to_i})")
      end
      app_response
     else
       @app.call(env)
     end
    end

    def should_writeout_data
      @analytics_data.size >= BUFFER_SIZE
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
  end
end
