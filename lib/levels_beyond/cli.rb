require 'rubygems'

require 'logger'
require 'optparse'

module LevelsBeyond

  module CLI

    LOGGING_LEVELS = {
      :debug => Logger::DEBUG,
      :info => Logger::INFO,
      :warn => Logger::WARN,
      :error => Logger::ERROR,
      :fatal => Logger::FATAL
    }

    class <<self

      attr_accessor :options

    end

    class CommonOptionParser < ::OptionParser

      attr_accessor :options

      #def options=(value)
      #  #puts "Setting #{self.class.name}[#{self.object_id}] options => (#{value.class.name}[#{value.object_id}]) #{value}"
      #  @options = value
      #end
      #
      #def options
      #  #puts "Getting #{self.class.name}[#{self.object_id}] options. #{@options}"
      #  @options
      #end

      def parse_arguments_from_options_file

      end

      def parse_arguments_from_command_line

      end

      def original_command_line_arguments
        @original_command_line_arguments
      end

      def remaining_command_line_arguments
        @remaining_command_line_arguments
      end

      def parse_common(command_line_arguments = ARGV, _options = (options || { }))
        parse_common!(command_line_arguments.dup, _options)
      end

      def parse_common!(command_line_arguments = ARGV, _options = (options || { }))
        #puts "Parsing #{self.class.name}[#{self.object_id}] options. #{@options}"

        @original_command_line_arguments = command_line_arguments.dup
        parse!(command_line_arguments)

        @remaining_command_line_arguments = command_line_arguments.dup

        options_file_path = _options[:options_file_path] #||= default_options_file_path

        # Make sure that options from the command line override those from the options file
        parse!(original_command_line_arguments.dup) if options_file_path and load(options_file_path)

        check_required_arguments
      end

      def required_arguments; @required_arguments ||= [ ] end
      def add_required_argument(*args)  [*args].each { |arg| required_arguments << arg } end
      alias :add_required_arguments :add_required_argument

      def missing_required_arguments
        required_arguments.dup.delete_if { |a| options.has_key?(a.is_a?(Hash) ? a.keys.first : a) }
      end

      def check_required_arguments
        _missing_arguments = missing_required_arguments
        unless _missing_arguments.empty?
          _missing_arguments = _missing_arguments.pop if _missing_arguments.first.is_a?(Array) # This is a work around where _missing_arguments comes back as an array of an array in Ruby 1.8.7
          abort "Missing Required Arguments: #{ _missing_arguments.map { |v| (v.is_a?(Hash) ? v.values.first : v).to_s.gsub('_', '-')  }.join(', ') }\n\n#{self.to_s}"
        end
      end

      def default_options_file_path
        file_path = File.join(File.expand_path('.'), "#{File.basename($0, '.rb')}_options")
        return file_path if File.exists?(file_path)
        return File.expand_path(File.basename($0, '.*'), '~/.options')
      end

    end # CommonOptionParser

    def self.new_common_option_parser(*args)
      op = CommonOptionParser.new(*args)
      op.options = options
      op
    end

  end

end
@cli_class ||= LevelsBeyond::CLI
def cli_class; @cli_class ||= LevelsBeyond::CLI end

@options = options ||= { } #HashTap.new
def options; @options ||= { } end
def common_option_parser(_options = options)
  @common_option_parser ||= begin
    #cli_class.options ||= _options
    op = cli_class.new_common_option_parser
    op.options = _options
    op
  end
end



def add_common_options(option_parser = common_option_parser, _options = (options || { }))
  _options[:log_to] ||= STDERR
  _options[:log_level] ||= 0
  _options[:options_file_path] ||= option_parser.default_options_file_path if option_parser.respond_to?(:default_options_file_path)
  option_parser.on('--[no-]options-file [FILENAME]', "\tdefault: #{_options[:options_file_path]}" ) { |v| _options[:options_file_path] = v }
  option_parser.on('--log-to FILENAME', 'Log file location.', "\tdefault: STDERR") { |v| _options[:log_to] = v }
  option_parser.on('--log-level LEVEL', LevelsBeyond::CLI::LOGGING_LEVELS.keys, "Logging level. Available Options: #{LevelsBeyond::CLI::LOGGING_LEVELS.keys.join(', ')}",
                          "\tdefault: #{LevelsBeyond::CLI::LOGGING_LEVELS.invert[_options[:log_level]]}") { |v| _options[:log_level] = LevelsBeyond::CLI::LOGGING_LEVELS[v] }
  option_parser.on('-h', '--help', 'Show this message.') { puts option_parser; exit }
end