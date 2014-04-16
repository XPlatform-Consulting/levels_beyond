require 'levels_beyond/reach_engine/http_handler'

module LevelsBeyond

  module ReachEngine

    class API

      class HTTPHandler

        DEFAULT_SERVER_ADDRESS = 'localhost'
        DEFAULT_SERVER_PORT = '8080'

        attr_accessor :logger, :log_request_body, :log_response_body, :log_pretty_print_body

        attr_reader :http

        attr_accessor :cookie

        attr_accessor :response, :parse_response, :error
        attr_accessor :logger, :api_key, :server_address, :server_port, :http

        attr_accessor :base_path, :base_query

        # @param [Hash] args
        # @option args [Logger] :logger
        # @option args [String] :log_to
        # @option args [Integer] :log_level
        # @option args [String] :server_address
        # @option args [Integer] :server_port
        def initialize(args = {})
          @logger = args[:logger] ? args[:logger].dup : Logger.new(args[:log_to] || STDOUT)
          logger.level = args[:log_level] if args[:log_level]

          #hostname = args[:server_address] ||= DEFAULT_SERVER_ADDRESS
          #port = args[:server_port] ||= DEFAULT_SERVER_PORT
          args[:server_address] ||= DEFAULT_SERVER_ADDRESS
          args[:server_port] ||= DEFAULT_SERVER_PORT

          #@http = Net::HTTP.new(hostname, port)
          @http = ReachEngine::HTTPHandler.new(args)

          @parse_response = args.fetch(:parse_response, true)
          @api_key = args[:api_key]
          @base_path = args[:api_base_path] ||= DEFAULT_BASE_PATH
          #@base_query = { :apiKey => api_key, :fetchIndex => 0, :fetchLimit => 50 }
          @base_query = { :apiKey => api_key }

        end

        def http=(new_http)
          @to_s = nil
          @http = new_http
        end

        # Returns the connection information in a URI format.
        # @return [String]
        def to_s
          #@to_s ||= "http#{http.use_ssl? ? 's' : ''}://#{http.address}:#{http.port}"
          @to_s ||= http.to_s
        end


        ##############

        def snake_case_to_lower_camel_case(string)
          string.gsub(/(?:_)(\w)/) { $1.upcase }
        end

        def hash_to_query(hash)
          return URI.encode(hash.map{|k,v| "#{snake_case_to_lower_camel_case(k.to_s)}=#{v}"}.join('&'))
        end

        def process_post_data(data, options = { })
          recursive = options.fetch(recursive, options.fetch(:process_post_data_recursively, true))
          case data
            when Array
              data.map { |d| process_post_data(d) }
            when Hash
              if recursive
                Hash[ data.map { |k,v| [ snake_case_to_lower_camel_case(k.to_s), process_post_data(v, options) ] } ]
              else
                Hash[ data.map { |k,v| [ snake_case_to_lower_camel_case(k.to_s), v ] } ]
              end
            else
              data
          end
        end

        def process_path(path, query = { })
          query = base_query.merge(query)
          query_str = hash_to_query(query)
          path = path[1..-1] while path.end_with?('/')
          path = "#{base_path}#{path}#{query_str and !query_str.empty? ? "?#{query_str}" : ''}"
          logger.debug { "Processed Path: #{path}"}
          path
        end

        # Executes a HTTP DELETE request
        # @param [String] path
        # @param [Hash] headers
        # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
        # it's content type. If content type is not supported then the response body is returned.
        #
        # If parse_response? is false then the response body is returned.
        def delete(path, query = { }, headers = {})
          clear_response
          path = process_path(path, query)
          @success_code = 204
          @response = http.delete(path, headers)
          parse_response? ? parsed_response : response.body
        end


        # Executes a HTTP GET request and returns the response
        # @param [String] path
        # @param [Hash] headers
        # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
        # it's content type. If content type is not supported then the response body is returned.
        #
        # If parse_response? is false then the response body is returned.
        def get(path, query = { }, headers = { })
          clear_response
          path = process_path(path, query)
          @success_code = 200
          @response = http.get(path, headers)
          parse_response? ? parsed_response : response.body
        end

        # Executes a HTTP POST request
        # @param [String] path
        # @param [String] data
        # @param [Hash] headers
        # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
        # it's content type. If content type is not supported then the response body is returned.
        #
        # If parse_response? is false then the response body is returned.
        def post(path, data = { }, query = { }, headers = { })
          clear_response
          path = process_path(path, query)
          @success_code = 201
          @response = http.post(path, data, headers)
          parse_response? ? parsed_response : response.body
        end

        # Formats data as form url encoded and calls {#http_post}
        # @param [String] path
        # @param [Hash] data
        # @param [Hash] headers
        # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
        # it's content type. If content type is not supported then the response body is returned.
        #
        # If parse_response? is false then the response body is returned.
        def post_form(path, data = { }, query = { }, headers = { })
          headers['Content-Type'] = 'application/x-www-form-urlencoded'
          data = process_post_data(data)
          #data_as_string = URI.encode_www_form(data)
          http.post(path, data, query, headers)
        end

        # Formats data as JSON and calls {#http_put}
        # @param [String] path
        # @param [Hash] data
        # @param [Hash] headers
        # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
        # it's content type. If content type is not supported then the response body is returned.
        #
        # If parse_response? is false then the response body is returned.
        def post_json(path, data = { }, query = { }, headers = { })
          headers['Content-Type'] ||= 'application/json'
          data = process_post_data(data)
          data_as_string = JSON.generate(data)
          post(path, data_as_string, query, headers)
        end

        #def post_form_multipart(path, data, headers = { })
        #  headers['Content-Type'] = 'multipart/form-data'
        #
        #end # http_post_form_multipart


        # Executes a HTTP PUT request
        # @param [String] path
        # @param [String] data
        # @param [Hash] headers
        # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
        # it's content type. If content type is not support then the respond body is returned.
        #
        # If parse_response? is false then the response body is returned.
        def put(path, data, headers = {})
          clear_response
          @success_code = 200
          @response = http.put(path, data, headers)
          parse_response? ? parsed_response : response.body
        end

        # Formats data as JSON and calls {#http_put}
        def put_json(path, data, headers = { })
          headers['content-type'] = 'application/json'
          data = process_post_data(data)
          data_as_string = JSON.generate(data)
          put(path, data_as_string, headers)
        end


        # The http response code that indicates success for the request being made.
        def success_code
          @success_code
        end

        # Returns true if the response code equals the success code that was set by the method.
        def success?
          return nil unless success_code
          response.code == success_code.to_s
        end

        def clear_response
          @error = { }
          @success_code = @response = @parsed_response = nil
        end

        # Returns true if the response body parsing option has been set to true.
        def parse_response?
          parse_response
        end

        # Parses the response body based on the response's content-type header value
        # @return [nil|String|Hash]
        #
        # Will pass through the response body unless the content type is supported.
        def parsed_response
          #logger.debug { "Parsing Response: #{response.content_type}" }
          return response unless response
          @parsed_response ||= case response.content_type
                                 when 'application/json'; response.body.empty? ? '' : JSON.parse(response.body)
                                 when 'text/html'; { } #HTMLResponseParser.parse(response.body)
                                 else; response.respond_to?(:to_hash) ? response.to_hash : response.to_s
                               end
          @parsed_response
        end # parsed_response


      end

    end

  end

end