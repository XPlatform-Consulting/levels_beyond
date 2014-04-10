# https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+REST+API+Reference

require 'logger'
require 'uri'

require 'levels_beyond/reach_engine/api/http_handler'

module LevelsBeyond

  module ReachEngine

    class API

      attr_accessor :response, :parse_response, :error
      attr_accessor :logger, :api_key, :server_address, :server_port, :http

      attr_accessor :base_path, :base_query

      def initialize(args = { })
        initialize_logger(args)

        @server_address = args[:server_address] || 'localhost'
        @server_port = args[:server_port] || 8080
        @api_key = args[:api_key]

        @parse_response = args.fetch(:parse_response, true)
        initialize_http_handler(args)
        @base_path = '/reachengine/api/v1/'
        #@base_query = { :apiKey => api_key, :fetchIndex => 0, :fetchLimit => 50 }
        @base_query = { :apiKey => api_key }
      end

      def initialize_logger(args = { })
        @logger = args[:logger] ||= Logger.new(STDERR)
      end

      def default_options
        @default_options
      end # default_options

      # Sets the AdobeAnywhere connection information.
      # @see HTTPHandler#new
      def initialize_http_handler(args = {})
        @http = HTTPHandler.new(args)
        logger.debug { "Connection Set: #{http.to_s}" }
      end

      def hash_to_query(hash)
        return URI.encode(hash.map{|k,v| "#{k}=#{v}"}.join('&'))
      end

      def process_path(path, query = { })
        query = base_query.merge(query)
        query_str = hash_to_query(query)
        path = path[1..-1] while path.end_with?('/')
        path = "#{base_path}#{path}#{query_str and !query_str.empty? ? "?#{query_str}" : ''}"
        logger.debug { "Processed Path: #{path}"}
        path
      end

      # Forces all eligible hash keys to lowercase symbols
      #
      # @param [Hash] hash
      def normalize_hash_keys(hash)
        return hash unless hash.is_a?(Hash)
        Hash[ hash.dup.map { |k,v| [ ( k.respond_to?(:downcase) ? k.downcase.to_sym : k ), v ] } ]
      end

      # @param [Array] params
      # @param [Hash]  args
      # @param [Hash]  options
      def process_addition_parameters(params, args, options = { })
        args = normalize_hash_keys(args)
        add_params = { }
        params.each do |k|
          if k.is_a?(Hash) then
            param_name = alias_name = k[:name]
            has_key = args.has_key?(param_name)
            [*k[:alias]].drop_while { |v| alias_name = v; has_key = args.has_key?(alias_name); !has_key } unless has_key
            has_default_value = k.has_key?(:default_value)
            next unless has_key or has_default_value
            value = has_key ? args[alias_name] : k[:default_value]
          else
            param_name =  k
            next unless args.has_key?(param_name)
            value = args[param_name]
          end
          #if value.is_a?(Array)
          #  param_options = k[:options] || { }
          #  join_array = param_options.fetch(:join_array, true)
          #  value = value.join(',') if join_array
          #end
          add_params[param_name] = value
        end
        add_params
      end

      # @param [Hash] params Parameters to merge into
      # @return [Hash]
      def merge_additional_parameters(params, add_params, args, options = { })
        params.merge(process_addition_parameters(add_params, args, options))
      end


      # Executes a HTTP DELETE request
      # @param [String] path
      # @param [Hash] headers
      # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
      # it's content type. If content type is not supported then the response body is returned.
      #
      # If parse_response? is false then the response body is returned.
      def http_delete(path, query = { }, headers = {})
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
      def http_get(path, query = { }, headers = { })
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
      def http_post(path, data = { }, query = { }, headers = { })
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
      def http_post_form(path, data = { }, headers = { })
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
        #data_as_string = URI.encode_www_form(data)
        #post(path, data_as_string, headers)
        clear_response
        @success_code = 201
        @response = http.post(path, data, headers)
        parse_response? ? parsed_response : response.body
      end

      # Formats data as JSON and calls {#http_put}
      # @param [String] path
      # @param [Hash] data
      # @param [Hash] headers
      # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
      # it's content type. If content type is not supported then the response body is returned.
      #
      # If parse_response? is false then the response body is returned.
      def http_post_json(path, data = { }, query = { }, headers = { })
        headers['Content-Type'] ||= 'application/json'
        data_as_string = JSON.generate(data)
        http_post(path, data_as_string, headers)
      end

      #def http_post_form_multipart(path, data, headers = { })
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
      def http_put(path, data, headers = {})
        clear_response
        @success_code = 200
        @response = http.put(path, data, headers)
        parse_response? ? parsed_response : response.body
      end

      # Formats data as JSON and calls {#http_put}
      def http_put_json(path, data, headers = { })
        headers['Content-Type'] = 'application/json'
        data_as_string = JSON.generate(data)
        http_put(path, data_as_string, headers)
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
                               when 'application/json'; JSON.parse(response.body)
                               when 'text/html'; { } #HTMLResponseParser.parse(response.body)
                               else; response.respond_to?(:to_hash) ? response.to_hash : response.to_s
                             end
        @parsed_response
      end # parsed_response

      def asset_search(args = { })
        # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Assets
        add_params = [
          { :name => :fetchIndex, :alias => :fetch_index, :default_value => 0 },
          { :name => :fetchLimit, :alias => :fetch_index, :default_value => 50 },
          :search
        ]
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('asset', query)
      end
      alias :assets :asset_search

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Asset+Details
      def asset_detail(id)
        http_get("asset/#{id}")
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Timelines
      def timeline_search(args = { })
        add_params = [
          { :name => :fetchIndex, :alias => :fetch_index, :default_value => 0 },
          { :name => :fetchLimit, :alias => :fetch_index, :default_value => 50 },
          :search
        ]
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('timeline', query)
      end
      alias :timelines :timeline_search

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Timeline+Detail
      def timeline_detail(id)
        http_get("timeline/#{id}")
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Timeline+Clips
      def timeline_clips(id)
        http_get("timeline/#{id}/clips")
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Clips
      def clip_search(args = { })
        add_params = [
          { :name => :fetchIndex, :alias => :fetch_index, :default_value => 0 },
          { :name => :fetchLimit, :alias => :fetch_index, :default_value => 50 },
          :search
        ]
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('clip', query)
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Clip+Detail
      def clip_detail(id)
        http_get("clip/#{id}")
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Collections
      def collection_search(args = { })
        add_params = [
          { :name => :fetchIndex, :alias => :fetch_index, :default_value => 0 },
          { :name => :fetchLimit, :alias => :fetch_index, :default_value => 50 },
          :search
        ]
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('collection', query)
      end
      alias :collections :collection_search

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Collection+Detail
      def collection_detail(id)
        http_get("collection/#{id}")
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Create+Collections
      def collection_create(name, metadata = { })
        data = { :name => name }
        data[:metadata] = metadata if metadata.respond_to?(:empty?) and !metadata.empty?
        http_post_json('collection', data)
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Add+Collection+Member
      def collection_member_add(collection_id, member_class, member_id)
        data = {
          :class => member_class,
          :id => member_id
        }
        http_post_json("collection/#{collection_id}/members", data)
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Remove+Collection+Member
      def collection_member_remove(collection_id, member_class, member_id)
        http_delete("collection/#{collection_id}/members/#{member_class}/#{member_id}")
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Collection+Members
      def collection_member_search(collection_id)
        http_get("collection/#{id}/members")
      end
      alias :collection_members :collection_member_search

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Query+Workflows
      def workflow_query(args = { })
        add_params = [ { :name => :subjectClass, :alias => :subject_class }]
        query = merge_additional_parameters(query, add_params, args)
        http_get('workflow', query)
      end
      alias :workflows :workflow_query

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Workflow+Detail
      def workflow_detail(workflow_id)
        http_get("workflow/#{workflow_id}")
      end

      # @param [String] id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      # @param [Hash] args
      # @option args [Hash] :context_data Defines other parameters for the search, such as workflowName or subjectClass.
      # @return [Hash]
      #   {
      #       "executionId": "1c966d63-8a60-4d95-b880-7c40e677c6c3",
      #       "workflowId": "_archiveCollectionContents",
      #       "workflowName": "Archive Collection Contents",
      #       "subjectClass": "AssetCollection",
      #       "subjectId": "f490e0d8-0f9b-4bb0-9bcf-3aff61a56bc4",
      #       "status": "EXECUTING",
      #       "lastUpdated": "2013-04-29T04:44:40.156+0000",
      #       "pctComplete": "0",
      #       "description": "[WorkflowExecution.1c966d63-8a60-4d95-b880-7c40e677c6c3.12461] (Archive Collection Contents)",
      #       "currentStep": "compress content files",
      #       "currentStepDescription": "compress content files"
      #   }
      #
      # (@see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Start+Workflow)
      def workflow_start(id, args = { })
        add_params = [ { :name => :contextData, :alias => :context_data } ]
        data = { }
        data = merge_additional_parameters(data, add_params, args)
        http_post("workflow/#{id}/start")
      end

      # @param [String] id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      def workflow_status(id)
        # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Get+Workflow+Execution+Status
        http_get("workflow/execution/#{id}")
      end

      # @param [String] id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      #
      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Stop+Workflow+Execution
      def workflow_stop(id)
        http_post("workflow/#{id}/stop")
      end

      # @param [String] id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      #
      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Resume+Workflow+Execution
      def workflow_resume(id)
        http_post("workflow/#{id}/resume")
      end

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Get+Watchfolders
      def watch_folder_search
        http_get('workflow/watchfolder')
      end
      alias :watch_folders :watch_folder_search

      # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Create+Watchfolder
      def watch_folder_create(args = { })
        name = args[:name]
        watch_folder = args[:watch_folder]
        workflow_key = args[:workflow_key]
        file_data_def = args[:file_data_def]

        data = {
          :name => name,
          :watchFolder => watch_folder,
          :workflowKey => workflow_key,
          :fileDataDef => file_data_def
        }

        add_params = [
          :enabled,
          { :name => :deleteOnSuccess, :alias => :delete_on_success },
          { :name => :maxConcurrent, :alias => :max_concurrent }
        ]
        data = merge_additional_parameters(data, add_params, args)
        http_post('workflow/watchfolder', data)
      end

      def watch_folder_enable(watch_folder_id)
        # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Enable+Watchfolder
        http_post("workflow/watchfolder/#{watch_folder_id}/enable")
      end

      def watch_folder_disable(watch_folder_id)
        # https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Enable+Watchfolder
        http_post("workflow/watchfolder/#{watch_folder_id}/disable")
      end

    end

  end

end