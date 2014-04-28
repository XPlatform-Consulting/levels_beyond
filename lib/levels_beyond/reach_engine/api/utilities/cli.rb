require 'pp'

require 'levels_beyond/cli'
require 'levels_beyond/reach_engine/api/utilities'


module LevelsBeyond

  module ReachEngine

    class API

      class Utilities

        class CLI

          def self.parse_command_line_arguments(command_line_arguments = ARGV)
            options = { }
            op = LevelsBeyond::CLI::CommonOptionParser.new
            op.options = options
            op.on('--reach-engine-server-address SERVERADDRESS', 'The Reach Engine server address.') { |v| options[:server_address] = v }
            op.on('--reach-engine-server-port SERVERPORT', 'The Reach Engine server port.') { |v| options[:server_port] = v }
            op.on('--api-key APIKEY', 'The API key to use when calling the api.') { |v| options[:api_key] = v }
            op.on('--method-name METHODNAME', 'The name of the method to call.') { |v| options[:method_name] = v }
            op.on('--method-arguments JSON', 'The a JSON string consisting of the arguments to pass to the method.') { |v| options[:method_arguments] = v }
            op.on('--[no-]log-request-body', 'Determines if the request body is logged.') { |v| options[:log_request_body] = v }
            op.on('--[no-]log-response-body', 'Determines if the response body is logged.') { |v| options[:log_response_body] = v }
            op.on('--[no-]log-pretty-print-body', 'Determines if the request and response bodies are pretty printed in the log output.') { |v| options[:log_pretty_print_body] = v }
            op.on('--[no-]pretty-print', 'Determines if the output JSON is pretty printed') { |v| options[:pretty_print] = v }

            add_common_options(op, options)

            op.add_required_argument :api_key#, :method_name, :method_arguments

            op.parse_common(command_line_arguments)

            remaining_command_line_arguments = op.remaining_command_line_arguments.dup
            options[:method_name] ||= remaining_command_line_arguments.shift
            options[:method_arguments] ||= remaining_command_line_arguments
            #pp options
            options
          end

          def self.run(args = { })
            command_line_arguments = args[:command_line_arguments] || ARGV
            arguments = parse_command_line_arguments(command_line_arguments)
            new(arguments)
          end

          attr_accessor :logger, :api

          def initialize(args = { })
            @logger = Logger.new(args[:log_to])
            logger.level = args[:log_level] if args[:log_level]
            args[:logger] = logger

            @api = LevelsBeyond::ReachEngine::API::Utilities.new(args)

            method_name = args[:method_name]

            if method_name
              if method_name == 'methods'
                methods = api.methods; methods -= Object.methods; methods.sort.each { |method| puts "#{method} #{api.method(method).parameters}" }
                return
              end
              response = api_send(method_name, args[:method_arguments], args)
              output_response(response, args)
            end
          end

          def output_response(response, args = { })
            if args[:pretty_print]
              response = JSON.parse(response) if response.is_a?(String) and response.lstrip.start_with?('{', '[')

              case response
                when Array, Hash;
                  puts JSON.pretty_generate(response)
                else
                  pp response
              end
            else
              response = JSON.generate(response) if response.is_a?(Hash) or response.is_a?(Array)
              puts response
            end
          end

          def parse_method_arguments(method_arguments)
            return method_arguments.map { |argument| parse_method_arguments(argument) } if method_arguments.is_a?(Array)
            return method_arguments unless method_arguments.is_a?(String)
            return method_arguments unless method_arguments.start_with?('{', '[')
            JSON.parse(method_arguments, :symbolize_names => true)
          end

          def api_send(method_name, method_arguments, options = {})
            method_name = method_name.to_sym
            parse_method_arguments = options.fetch(parse_method_arguments, true)
            logger.debug { "Executing Method: #{method_name}" }

            send_arguments = [ method_name ]

            if method_arguments
              if method_arguments.is_a?(Array)
                send_arguments = send_arguments + ( parse_method_arguments ? parse_method_arguments(method_arguments) : method_arguments )
              else
                method_arguments = parse_method_arguments(method_arguments)
                send_arguments << method_arguments
              end
            end

            logger.debug { "Send Arguments: #{send_arguments.inspect}" }
            api.send(*send_arguments)
          end

        end

      end

    end

  end

end

# op = common_option_parser
# op.on('--reach-engine-server-address SERVERADDRESS', 'The Reach Engine server address.') { |v| options[:server_address] = v }
# op.on('--reach-engine-server-port SERVERPORT', 'The Reach Engine server port.') { |v| options[:server_port] = v }
# op.on('--api-key APIKEY', 'The API key to use when calling the api.') { |v| options[:api_key] = v }
# op.on('--method-name METHODNAME', 'The name of the method to call.') { |v| options[:method_name] = v }
# op.on('--method-arguments JSON', 'The a JSON string consisting of the arguments to pass to the method.') { |v| options[:method_arguments] = v }
# op.on('--[no-]log-request-body', 'Determines if the request body is logged.') { |v| options[:log_request_body] = v }
# op.on('--[no-]log-response-body', 'Determines if the response body is logged.') { |v| options[:log_response_body] = v }
# op.on('--[no-]log-pretty-print-body', 'Determines if the request and response bodies are pretty printed in the log output.') { |v| options[:log_pretty_print_body] = v }
# op.on('--[no-]pretty-print', 'Determines if the output JSON is pretty printed') { |v| options[:pretty_print] = v }
#
# op.add_required_argument :api_key#, :method_name, :method_arguments
#
# add_common_options
# op.parse_common
#
# remaining_command_line_arguments = op.remaining_command_line_arguments.dup
# options[:method_name] ||= remaining_command_line_arguments.shift
# options[:method_arguments] ||= remaining_command_line_arguments
#
# LevelsBeyond::ReachEngine::API::Utilities::CLI.new(options)
# exit

