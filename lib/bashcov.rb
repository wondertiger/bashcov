require 'optparse'
require 'ostruct'
require 'bashcov/version'
require 'bashcov/lexer'
require 'bashcov/line'
require 'bashcov/runner'
require 'bashcov/xtrace'

# Bashcov default module
# @note Keep it short!
module Bashcov
  class << self
    # @return [OpenStruct] Bashcov settings
    attr_reader :options

    # Sets default options overriding any existing ones.
    # @return [void]
    def set_default_options!
      @options ||= OpenStruct.new
      @options.skip_uncovered = false
      @options.mute = false
    end

    # Parses the given CLI arguments and sets +options+.
    # @param [Array] args list of arguments
    # @raise [SystemExit] if invalid arguments are given
    # @return [void]
    def parse_options! args
      option_parser.parse!(args)

      if args.empty?
        abort("You must give exactly one command to execute.")
      else
        @options.command = args.join(' ')
      end
    end

    # @return [String] The project's root directory
    def root_directory
      Dir.getwd
    end

    # Program name including version for easy consistent output
    # @return [String]
    def name
      "bashcov v#{VERSION}"
    end

    # Helper to get a pre-filled coverage array for a given file
    # @todo This is generic and should be moved in some helpers file.
    # @api private
    # @param [String] filename The file to cover.
    # @param [nil, Integer] fill Value to fill the array with.
    # @return [Array] An array of the size of the given file.
    # @example
    #   coverage_array('file.rb') #=> [0, 0, 0] # assuming file.rb has 3 lines
    def coverage_array(filename, fill = Line::UNCOVERED)
      lines = File.open(filename).read.count $/
      [fill] * lines
    end

  private

    def option_parser
      OptionParser.new do |opts|
        opts.program_name = 'bashcov'
        opts.version = Bashcov::VERSION
        opts.banner = <<-HELP.gsub!(/^ +/, '').gsub!("\t", ' ' * 4)
          Usage: #{opts.program_name} [options] [--] <command> [options]
          Examples:
          \t#{opts.program_name} ./script.sh
          \t#{opts.program_name} --skip-uncovered ./script.sh
          \t#{opts.program_name} -- ./script.sh --some --flags
          \t#{opts.program_name} --skip-uncovered -- ./script.sh --some --flags
        HELP

        opts.separator "\nSpecific options:"

        opts.on("-s", "--skip-uncovered", "Do not report uncovered files") do |s|
          @options.skip_uncovered = s
        end

        opts.on("-m", "--mute", "Do not print script output") do |m|
          @options.mute = m
        end

        opts.separator "\nCommon options:"

        opts.on_tail("-h", "--help", "Show this message") do
          abort(opts.help)
        end

        opts.on_tail("--version", "Show version") do
          puts opts.ver
          exit
        end
      end
    end
  end
end

# Make sure default options are set
Bashcov.set_default_options!
