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

      DEFAULT_FETCH_INDEX = 0
      DEFAULT_FETCH_LIMIT = 50

      DEFAULT_SERVER_ADDRESS = 'localhost'
      DEFAULT_SERVER_PORT = 8080
      DEFAULT_BASE_PATH = '/reachengine/api/v1/'

      API_METHOD_PARAMETERS = { }

      def initialize(args = { })
        initialize_logger(args)

        @server_address = args[:server_address] || DEFAULT_SERVER_ADDRESS
        @server_port = args[:server_port] || DEFAULT_SERVER_PORT
        @api_key = args[:api_key]

        @parse_response = args.fetch(:parse_response, true)
        initialize_http_handler(args)

        @base_path = args[:api_base_path] ||= DEFAULT_BASE_PATH
        #@base_query = { :apiKey => api_key, :fetchIndex => 0, :fetchLimit => 50 }
        @base_query = { :apiKey => api_key }
      end

      def initialize_logger(args = { })
        @logger = args[:logger] ||= Logger.new(STDERR)
      end

      def default_options
        @default_options
      end # default_options

      def cached_method_parameters
        @cached_method_parameters ||= { }
      end

      # Sets the AdobeAnywhere connection information.
      # @see HTTPHandler#new
      def initialize_http_handler(args = {})
        @http = HTTPHandler.new(args)
        logger.debug { "Connection Set: #{http.to_s}" }
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

      def snake_case_to_lower_camel_case(string)
        string.gsub(/(?:_)(\w)/) { $1.upcase }
      end

      # @param [Symbol|String] parameter_name A symbol or string in snake case form
      def normalize_arguments(arguments, options = { })
        recursive = options.fetch(:recursive, options[:normalize_arguments_recursively])
        if recursive
          arguments = Hash[arguments.dup.map { |k,v| [ ( k.respond_to?(:to_s) ? k.to_s.gsub('_', '').downcase : k ),  ( v.is_a?(Hash) ? normalize_arguments(v, options) : v ) ] } ]
        else
          arguments = Hash[arguments.dup.map { |k,v| [ ( k.respond_to?(:to_s) ? k.to_s.gsub('_', '').downcase : k ) , v ] } ]
        end
        arguments
      end

      def filter_arguments(arguments, parameter_names, options = { })
        parameter_names_normalized = Hash[[*parameter_names].map { |param_name| [ param_name.to_s.gsub('_', '').downcase, param_name ] } ]
        arguments_normalized = normalize_arguments(arguments, options)
        logger.debug { "Normalized Arguments: #{PP.pp(arguments_normalized, '')}"}
        filtered_arguments = {}

        arguments_normalized.dup.each do |k,v|
          param_name = parameter_names_normalized.delete(k)
          logger.debug { "Parameter '#{k}' Not Found" } and next unless param_name
          logger.debug { "Setting Parameter '#{param_name}' => #{v.inspect}" }
          filtered_arguments[param_name] = v
          break if parameter_names_normalized.empty?
        end

        return filtered_arguments
      end


      def process_parameters(parameters, arguments, options = { })
        defaults = { }
        parameter_names = [ ]
        required_parameters = { }
        parameters.each do |param|
          if param.is_a?(Hash)
            parameter_name = param[:alias] || param[:name]
            defaults[parameter_name] = param[:default_value] if param.has_key?(:default_value)
            required_parameters[parameter_name] = param if param[:required]
          else
            parameter_name = param
          end
          parameter_names << parameter_name
        end
        logger.debug { "Processing Parameters: #{parameter_names}" }
        arguments_out = defaults.merge(filter_arguments(arguments, parameter_names, options))
        missing_required_parameters = required_parameters.keys - arguments_out.keys
        raise ArgumentError, "Missing Required Parameters: #{missing_required_parameters.join(', ')}" unless missing_required_parameters.empty?
        return arguments_out
      end

      # @param [Hash] params Parameters to merge into
      # @return [Hash]
      def merge_additional_parameters(params, add_params, args, options = { })
        params.merge(process_parameters(add_params, args, options))
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
      def http_post_form(path, data = { }, query = { }, headers = { })
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
      def http_post_json(path, data = { }, query = { }, headers = { })
        headers['Content-Type'] ||= 'application/json'
        data = process_post_data(data)
        data_as_string = JSON.generate(data)
        http_post(path, data_as_string, query, headers)
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
        headers['content-type'] = 'application/json'
        data = process_post_data(data)
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
                               when 'application/json'; response.body.empty? ? '' : JSON.parse(response.body)
                               when 'text/html'; { } #HTMLResponseParser.parse(response.body)
                               else; response.respond_to?(:to_hash) ? response.to_hash : response.to_s
                             end
        @parsed_response
      end # parsed_response


      def api_method_parameters(method_name)
        cached_method_parameters[method_name] ||= API_METHOD_PARAMETERS[method_name]
      end

      # @!group API Methods

      # The Asset Search method uses a search term, as well as optional parameters, to find assets within the Reach
      # Engine Studio. The method returns a list of assets that matches the parameters provided, if any. If no search
      # term or other parameters are specified, the response contains up to 50 assets. More assets can be returned with
      # additional Find Assets requests using the FetchIndex parameter.
      #
      # @param [Hash] args
      # @option args [String] :search The term to match against. Search terms are sent through a search engine, and
      # search all text in a document. Search supports partial words and similar words, but not wild cards. If no
      # parameter is offered, all assets are returned up to the default limit of 50.
      # @option args [String] :media Limits the media types returned. Valid values are "video", "audio", or "image".
      # @option args [Integer] :fetch_index Defines the start index of the results. E.g., "15" would start the results
      # on the fifteenth item returned. Used with fetchLimit for pagination controls.
      # @option args [Integer] :fetch_limit Defines the maximum number of results to return per page. If omitted, the
      # search is limited to 50 results.
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Assets
      def asset_find(args = { })
        add_params = api_method_parameters(__method__)
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('asset', query)
      end
      alias :assets :asset_find
      alias :asset_search :asset_find
      API_METHOD_PARAMETERS[:asset_find] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
        :search,
      ]

      # The Asset Detail method uses an asset ID (that can be found using the Find Assets method) to view asset details
      # such as name, asset type, and media information (e.g., for video, information includes duration,
      # audio language, aspect ratio, and mime type).
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Asset+Details
      def asset_detail(id)
        http_get("asset/#{id}")
      end

      # The Find Timelines method uses a search term to find timelines within the Reach Engine Studio. The method 
      # returns a list of timelines that matches the parameters provided, if any. If no search term or other parameters 
      # are specified, the response contains up to 50 timelines. More timelines can be returned with additional Find 
      # Timelines requests using the FetchIndex parameter.
      #
      # @param [Hash] args
      # @option args [String] :search The term to match against. Search terms are sent through a search engine, and
      # search all text in a document. Search supports partial words and similar words, but not wild cards. If no
      # parameter is offered, all assets are returned up to the default limit of 50.
      # @option args [String] :media Limits the media types returned. Valid values are "video", "audio", or "image".
      # @option args [Integer] :fetch_index Defines the start index of the results. E.g., "15" would start the results
      # on the fifteenth item returned. Used with fetchLimit for pagination controls.
      # @option args [Integer] :fetch_limit Defines the maximum number of results to return per page. If omitted, the
      # search is limited to 50 results.
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Timelines
      def timeline_find(args = { })
        add_params = api_method_parameters(__method__)
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('timeline', query)
      end
      alias :timelines :timeline_find
      alias :timeline_search :timeline_find
      API_METHOD_PARAMETERS[:timeline_find] = [
          { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
          { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
          :search,
      ]

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Timeline+Detail
      def timeline_detail(id)
        http_get("timeline/#{id}")
      end

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Timeline+Clips
      def timeline_clips(id)
        http_get("timeline/#{id}/clips")
      end

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Clips
      def clip_find(args = { })
        add_params = api_method_parameters(__method__)
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('clip', query)
      end
      API_METHOD_PARAMETERS[:clip_search] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
        :search,
      ]

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Clip+Detail
      def clip_detail(id)
        http_get("clip/#{id}")
      end

      # The Find Collections method uses a search term to find collections within the Reach Engine Studio.
      # If no search term or other parameters are provided, the response contains up to 50 collections.
      # More collections can be returned with additional Find Collections requests using the Fetch Index parameter.
      #
      # @param [Hash] args
      # @option args [String] :search
      # @option args [Integer] :fetch_index
      # @option args [Integer] :fetch_limit
      # @return [Hash]
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Collections
      def collection_find(args = { })
        add_params = api_method_parameters(__method__)

        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('collection', query)
      end
      alias :collections :collection_find
      alias :collection_search :collection_find
      API_METHOD_PARAMETERS[:collection_find] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
        :search,
      ]

      # Collection Details uses a collection ID (found using the Find Collections method) to view details about
      # specific collection. Details returned in the response include geographic information as well as review comments.
      #
      # @param [String] id The UUID (universally unique identifier) of the collection
      # @return [Hash]
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Collection+Detail
      def collection_detail(id)
        http_get("collection/#{id}")
      end

      # Creates a new collection, ready for member insertion, using the collection name provided in the request. After
      # a new collection is created, use the Add Collection Member methods to add member items.
      #
      # Note: For collection naming conventions, spaces and special characters are allowed, as well as duplicate names.
      # What differentiates same-name collections is the meta data (image, timestamp, etc.) and the reference ID.
      #
      # @param [String] name The name of the Collection to be created.
      # @param [Hash] metadata A hash with metadata key/value pairs for this collection.
      def collection_create(name, metadata = { })
        data = { :name => name }
        data[:metadata] = metadata if metadata.respond_to?(:empty?) and !metadata.empty?
        http_post_json('collection', data)
      end

      # The Collection Member Add method sends a collection ID and specifies the asset type and ID to add to the
      # collection. IDs are automatically created when a video is uploaded. Only one collection member can be
      # added in a single request.
      #
      # The Collection Member Add response contains information about the clip, including the clip name (provided by
      # the user when the clip was created) and clip ID. The response displays all associated members in the response;
      # therefore, if collection members have been added during a prior request, the existing collection members, in
      # addition to the newly added collection member, will all display in the response.
      #                                                                                                                                                                                                                                                                                                                                                                                                                    #
      # @param [String] collection_id The Collection UUID (universally unique identifier).
      # @param [String] member_class The type of the asset to be added to the Collection.
      #                              Valid values include "AssetMaster", "Timeline", and "Clip".
      # @param [String] member_id The UUID (universally unique identifier) of the asset.
      # @return [Array<Hash>]
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Add+Collection+Member
      def collection_member_add(collection_id, member_class, member_id)
        data = {
          :class => member_class,
          :id => member_id
        }
        http_post_json("collection/#{collection_id}/members", data)
      end

      # The Collection Member Remove method sends a collection ID and specifies the member class and member ID to
      # remove from the collection. To determine the member class and ID, use the Collection Member method. No more
      # than one member can be removed in a single request.
      #
      # @param [String] collection_id The Collection UUID (universally unique identifier).
      # @param [String] member_class The class of the member to remove. This value should match the "class" property in
      # the member JSON structure from a query result.
      # @param [String] member_id The UUID of the member to remove. This value should match the "id" property in the
      # member JSON structure from a query result.
      # @return [Array<Hash>]
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Remove+Collection+Member
      def collection_member_remove(collection_id, member_class, member_id)
        http_delete("collection/#{collection_id}/members/#{member_class}/#{member_id}")
      end

      # A collection member is an asset within a collection. An asset collection contains collection members, and
      # assets can belong to more than one collection. However, it is not possible to nest collections (you cannot have
      # a collection of collections).
      #
      # @param [String] collection_id
      # @return [Array<Hash>]
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Collection+Members
      def collection_member_find(collection_id)
        http_get("collection/#{collection_id}/members")
      end
      alias :collection_members :collection_member_find
      alias :collection_member_search :collection_member_find

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Query+Workflows
      def workflow_query(args = { })
        add_params = [ :subject_class ]
        query = { }
        query = merge_additional_parameters(query, add_params, args)
        http_get('workflow', query)
      end
      alias :workflows :workflow_query

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Workflow+Detail
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
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Start+Workflow
      def workflow_execution_start(id, args = { })
        add_params = [ { :name => :context_data } ]
        data = { }
        data = merge_additional_parameters(data, add_params, args)
        http_post_json("workflow/#{id}/start", data)
      end

      # @param [String] id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Get+Workflow+Execution+Status
      def workflow_execution_status(id)

        http_get("workflow/execution/#{id}")
      end

      # @param [String] id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Stop+Workflow+Execution
      def workflow_execution_stop(id)
        http_post("workflow/#{id}/stop")
      end

      # @param [String] id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Resume+Workflow+Execution
      def workflow_execution_resume(id)
        http_post("workflow/#{id}/resume")
      end

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Get+Watchfolders
      def watch_folder_find
        http_get('workflow/watchfolder')
      end
      alias :watch_folders :watch_folder_find
      alias :watch_folder_search :watch_folder_find

      # Creates a new watchfolder at the configured path. By default, watchfolders are created but not enabled.
      # To enable a watchfolder, either set the "enabled" property when creating, or call the /enable method later.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Create+Watchfolder
      #
      # @param [Hash] args
      # @option args [String] :name The name of the watchfolder to be created.
      # @option args [String] :watch_folder The file system path to the new watchfolder.
      # @option args [String] :workflow_key The ID of the workflow to call when a file is placed into the watchfolder.
      # @option args [String] :file_data_def The file that is detected in the watchfolder must be assigned to a data
      # def in the workflow defined by workflowKey. This value must match a File data def in the target workflow.
      # @option args [String] :subject
      # @option args [Boolean] :enabled Whether or not the watchfolder is enabled. Defaults to "false".
      # @option args [Boolean] :delete_on_success Whether to delete the file in the watchfolder after processing.
      # Defaults is "false".
      # @option args [Integer] :max_concurrent The maximum number of files to process at a time. Defaults to 1.
      # @option args [Hash] :context_data Optionally pass other context data into the workflow defined by workflowKey
      # when a file is to be processed by the workflow. This hash's keys should each be the name of a data def in the
      # workflow, and the value being a valid value for the data def's type
      # (i.e., if type is "Integer" value must be a valid number).
      def watch_folder_create(args = { })
        parameters = api_method_parameters(__method__)
        data = process_parameters(parameters, args)

        # # FORCE SUBJECT TO BE AN ARRAY
        # subject = data[:subject]
        # data[:subject] = [*subject] if subject

        return http_post_json('workflow/watchfolder', data)
      end
      API_METHOD_PARAMETERS[:watch_folder_create] = [
        { :name => :name,           :required => true },
        { :name => :watch_folder,   :required => true },
        { :name => :workflow_key,   :required => true },
        { :name => :file_data_def,  :required => true },
        :subject,
        :enabled,
        :delete_on_success,
        :max_concurrent,
        :context_data
      ]

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Enable+Watchfolder
      def watch_folder_enable(watch_folder_id)

        http_post("workflow/watchfolder/#{watch_folder_id}/enable")
      end

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Enable+Watchfolder
      def watch_folder_disable(watch_folder_id)

        http_post("workflow/watchfolder/#{watch_folder_id}/disable")
      end

      def search(args = { })
        types = args[:types]
        rql = args[:rql] || args[:query]

        query = {}
        query[:types] = [*types].join('|') if types
        query[:rql] = rql if rql
        http_get('search', query)
      end
      API_METHOD_PARAMETERS[:search] = [ :types, :rql ]

      # @!endgroup

    end

  end

end