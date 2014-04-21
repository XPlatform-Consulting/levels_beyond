require 'sinatra/base'
require 'levels_beyond/reach_engine/api/utilities'
module LevelsBeyond

  module ReachEngine

    class API

      class HTTPServer < Sinatra::Base

        enable :logging
        disable :protection

        # ROUTES BEGIN
        post('/api') { handle_request_api }
        # ROUTES END

        def self.init(args = { })
          args.each { |k,v| set(k, v) }
          def logger; settings.logger end if settings.logger
        end # new

        def format_response(response, args = { })
          supported_types = [ 'application/json', 'application/xml', 'text/xml', 'text/html' ]
          case request.preferred_type(supported_types)
            when 'application/json'
              content_type :json
              _response = response.is_a?(Hash) || response.is_a?(Array) ? JSON.generate(response) : response
            #when 'application/xml', 'text/xml'
            #  content_type :xml
            #  _response = XmlSimple.xml_out(response, { :root_name => 'response' })
            when 'text/html'
              content_type :html
              _response = PP.pp(response, '').sub("\n", '<br/>')
            else
              content_type :json
              _response = response.is_a?(Hash) || response.is_a?(Array) ? JSON.generate(response) : response
          end
          _response
        end # output_response

        # Will try to convert a body to arguments and merge them into the args hash
        # Arguments from the uri query and form data will override the body arguments
        #
        # @params [Hash] args (params) The arguments parsed from the query and form fields
        def merge_args_from_body(args = params, options = { })
          normalize_incoming_hash = options.fetch(:normalize_incoming_hash, true)
          _args = normalize_incoming_hash ? normalize_arguments_hash_keys(args) : args.dup

          if request.media_type == 'application/json'
            request.body.rewind
            body_contents = request.body.read
            logger.debug { "Parsing: '#{body_contents}'" }
            if body_contents
              json_args = JSON.parse(body_contents)
              if json_args.is_a?(Hash)
                #json_params = indifferent_hash.merge(json_params)
                _args = normalize_arguments_hash_keys(json_args).merge(_args)
              else
                _args['body'] = json_args
              end
            end
            _args
          end

          _args
        end # merge_params_from_body

        def normalize_arguments_hash_keys(arguments)
          Hash[arguments.map { |k,v| [ normalize_argument_key(k), v ] }]
        end

        # Turns CamelCase, Train-Case, and spinal-case into lower snake_case
        # 'some-value' => 'some_value'
        # 'lowerCamelCase' => 'lower_camel_case'
        def normalize_argument_key(key)
          #key.to_s.gsub('-', '_').gsub(/(?=\w|^)([A-Z])/) { "_#{$1.downcase}" }.downcase
          key.to_s.gsub('-', '_').sub(/^([A-Z])/) { $1.downcase }.gsub(/(?=\w?)([A-Z])/) { "_#{$1}" }.downcase
        end

        # @param [Hash] args
        # @option args [String] :method_name (Required)
        # @option args [String] :method_arguments (Optional)
        # @option args [String] :host_address
        # @option args [String|Integer] :port
        # @option args [String] :username
        # @option args [String] :password
        def handle_request_api(args = params)
          args = merge_args_from_body(args)

          re_args = { :logger => settings.logger }
          re_args[:server_address] = args['server_address'] || settings.reach_engine_default_server_address
          re_args[:server_port] = args['server_port'] || settings.reach_engine_default_server_port
          re_args[:api_key] = args['api_key'] || settings.reach_engine_default_api_key
          #logger.debug { "AA Args: #{aa_args}" }
          begin
            api = LevelsBeyond::ReachEngine::API::Utilities.new(re_args)
          rescue => e
            logger.warn { "Exception while instantiating Reach Engine API. #{e.message}\nBacktrace:\n#{e.backtrace}" }
            return format_response({ :exception => { :message => e.message, :backtrace => e.backtrace } })
          end

          method_name = args['method_name']
          return format_response({ :error => { :message => ':method_name is a required argument.' } }) unless method_name

          method_name = method_name.sub('-', '_').to_sym
          method_arguments = args['method_arguments'] || args['arguments']
          method_arguments = JSON.parse(method_arguments) rescue method_arguments if method_arguments.is_a?(String)
          logger.debug { "\nMethod Name: #{method_name}\nArguments: #{method_arguments}" }

          send_args = [ method_name ]
          send_args << method_arguments if method_arguments
          @safe_methods ||= api.methods - Object.new.methods
          if @safe_methods.include?(method_name)
            begin
              _response = api.send(*send_args)
            rescue => e
              logger.warn { "Error executing api command. #{e.message}\nBacktrace:\n#{e.backtrace}" }
              _response = { :exception => { :message => e.message, :backtrace => e.backtrace } }
            end
          else
            _response = { :error => "#{method_name} is not a valid method name." }
          end
          logger.debug { "Response: #{_response}" }
          format_response(_response)
        end # handle_request_api

      end

    end

  end

end
