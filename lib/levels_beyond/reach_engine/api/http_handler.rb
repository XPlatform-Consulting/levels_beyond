require 'json'
require 'net/http'
module LevelsBeyond

  module ReachEngine

    class API

      class HTTPHandler

        DEFAULT_SERVER_ADDRESS = 'localhost'
        DEFAULT_SERVER_PORT = '8080'

        attr_accessor :logger, :log_request_body, :log_response_body, :log_pretty_print_body

        attr_reader :http

        attr_accessor :cookie

        # @param [Hash] args
        # @option args [Logger] :logger
        # @option args [String] :log_to
        # @option args [Integer] :log_level
        # @option args [String] :server_address
        # @option args [Integer] :server_port
        def initialize(args = {})
          @logger = args[:logger] ? args[:logger].dup : Logger.new(args[:log_to] || STDOUT)
          logger.level = args[:log_level] if args[:log_level]

          hostname = args[:server_address] || DEFAULT_SERVER_ADDRESS
          port = args[:server_port] || DEFAULT_SERVER_PORT
          @http = Net::HTTP.new(hostname, port)
          @log_request_body = args[:log_request_body]
          @log_response_body = args[:log_response_body]
          @log_pretty_print_body = args[:log_pretty_print_body]
        end

        def http=(new_http)
          @to_s = nil
          @http = new_http
        end

        # Formats a HTTPRequest or HTTPResponse body for log output.
        # @param [HTTPRequest|HTTPResponse] obj
        # @return [String]
        def format_body_for_log_output(obj)
          #obj.body.inspect
          output = ''
          if obj.content_type == 'application/json'
            if @log_pretty_print_body
              output << "\n"
              output << JSON.pretty_generate(JSON.parse(obj.body))
              return output
            else
              return obj.body
            end
          else
            return obj.body.inspect
          end
        end # pretty_print_body

        # Performs final processing of a request then executes the request and returns the response.
        #
        # Debug output for all requests and responses is also handled by this method.
        # @param [HTTPRequest] request
        def process_request(request)

          logger.debug { %(REQUEST: #{request.method} #{to_s}#{request.path} HEADERS: #{request.to_hash.inspect} #{log_request_body and request.request_body_permitted? ? "BODY: #{format_body_for_log_output(request)}" : ''}) }
          request_time_start = Time.now
          response = http.request(request)
          request_time_stop = Time.now
          request_time_elapsed = request_time_stop - request_time_start
          logger.debug { %(RESPONDED IN #{request_time_elapsed} seconds. RESPONSE: #{response.inspect} HEADERS: #{response.to_hash.inspect} #{log_response_body and response.respond_to?(:body) ? "BODY: #{format_body_for_log_output(response)}" : ''}) }

          response
        end # process_request

        # Creates a HTTP DELETE request and passes it to {#process_request} for final processing and execution.
        # @param [String] path
        # @param [Hash] headers
        def delete(path, headers)
          http_to_s = to_s
          path = path.sub(http_to_s, '') if path.start_with?(http_to_s)
          path = "/#{path}" unless path.start_with?('/')
          request = Net::HTTP::Delete.new(path, headers)
          process_request(request)
        end

        # Creates a HTTP GET request and passes it to {#process_request} for final processing and execution.
        # @param [String] path
        # @param [Hash] headers
        def get(path, headers)
          http_to_s = to_s
          path = path.sub(http_to_s, '') if path.start_with?(http_to_s)
          path = "/#{path}" unless path.start_with?('/')
          request = Net::HTTP::Get.new(path, headers)
          process_request(request)
        end

        # Processes put and post request bodies based on the request content type and the format of the data
        # @param [HTTPRequest] request
        # @param [Hash|String] data
        def process_put_and_post_requests(request, data)
          content_type = request['Content-Type'] ||= 'application/x-www-form-urlencoded'
          case content_type
            when 'application/x-www-form-urlencoded'; request.form_data = data
            when 'application/json'; request.body = (data.is_a?(Hash) or data.is_a?(Array)) ? JSON.generate(data) : data
            else
              #data = data.to_s unless request.body.is_a?(String)
              request.body = data
          end
          process_request(request)
        end

        # Creates a HTTP POST request and passes it on for execution
        # @param [String] path
        # @param [String|Hash] data
        # @param [Hash] headers
        def post(path, data, headers)
          path = "/#{path}" unless path.start_with?('/')
          request = Net::HTTP::Post.new(path, headers)
          process_put_and_post_requests(request, data)
        end

        # Creates a HTTP PUT request and passes it on for execution
        # @param [String] path
        # @param [String|Hash] data
        # @param [Hash] headers
        def put(path, data, headers)
          path = "/#{path}" unless path.start_with?('/')
          request = Net::HTTP::Put.new(path, headers)
          process_put_and_post_requests(request, data)
        end

        #def post_form_multipart(path, data, headers)
        #  #headers['Cookie'] = cookie if cookie
        #  #path = "/#{path}" unless path.start_with?('/')
        #  #request = Net::HTTP::Post.new(path, headers)
        #  #request.body = data
        #  #process_request(request)
        #end

        # Returns the connection information in a URI format.
        # @return [String]
        def to_s
          @to_s ||= "http#{http.use_ssl? ? 's' : ''}://#{http.address}:#{http.port}"
        end

      end

    end

  end

end