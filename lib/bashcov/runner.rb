require 'open4'

module Bashcov
  # Runs a given command capturing output then computes code coverage.
  class Runner
    # @return [Array] +stdout+ from the last run
    attr_reader :stdout

    # @return [Array] +stderr+ from the last run
    attr_reader :stderr

    # @param [String] filename Command to run
    def initialize filename
      @filename = File.expand_path(filename)
    end

    # Runs the command capturing +stdout+ and +stderr+.
    # @note Binds Bashcov +stdin+ to the program executed.
    # @note Uses two threads to stream +stdout+ and +stderr+ output in
    #   realtime.
    # @return [void]
    def run
      setup

      Open4::popen4(@command) do |pid, stdin, stdout, stderr|
        stdin = $stdin # bind stdin

        [
          Thread.new { # stdout
            stdout.each do |line|
              $stdout.puts line unless Bashcov.options.mute
              @stdout << line
            end
          },
          Thread.new { # stderr
            stderr.each do |line|
              unless Bashcov.options.mute
                xtrace = Xtrace.new [line]
                $stderr.puts line if xtrace.xtrace_output.empty?
              end
              @stderr << line
            end
          }
        ].map(&:join)
      end
    end

    # @return [Hash] Coverage hash of the last run
    def result
      if Bashcov.options.skip_uncovered
        files = {}
      else
        files = find_bash_files "#{Bashcov.root_directory}/**/*.sh"
      end

      files = add_coverage_result files
      files = ignore_irrelevant_lines files
    end

    # @param [String] directory Directory to scan
    # @return [Hash] Coverage hash of Bash files in the given +directory+. All
    #   files are marked as uncovered.
    def find_bash_files directory
      files = {}

      Dir[directory].each do |file|
        absolute_path = File.expand_path(file)
        next unless File.file?(absolute_path)

        files[absolute_path] = Bashcov.coverage_array(absolute_path)
      end

      files
    end

    # @param [Hash] files Initial coverage hash
    # @return [Hash] Given hash including coverage result from {Xtrace}
    # @see Xtrace
    def add_coverage_result files
      xtraced_files = Xtrace.new(@stderr).files

      xtraced_files.each do |file, lines|
        lines.each_with_index do |line, lineno|
          files[file] ||= Bashcov.coverage_array(file)
          files[file][lineno] = line if line
        end
      end

      files
    end

    # @param [Hash] files Initial coverage hash
    # @return [Hash] Given hash ignoring irrelevant lines
    # @see Lexer
    def ignore_irrelevant_lines files
      files.each do |filename, lines|
        lexer = Lexer.new(filename)
        lexer.irrelevant_lines.each do |lineno|
          files[filename][lineno] = Bashcov::Line::IGNORED
        end
      end
    end

  private

    def setup
      inject_xtrace_flag

      @stdout = []
      @stderr = []

      @command = "PS4='#{Xtrace.ps4}' #{@filename}"
    end

    def inject_xtrace_flag
      # SHELLOPTS must be exported so we use Ruby's ENV variable
      existing_flags = (ENV['SHELLOPTS'] || '').split(':')
      ENV['SHELLOPTS'] = (existing_flags | ['xtrace']).join(':')
    end
  end
end

