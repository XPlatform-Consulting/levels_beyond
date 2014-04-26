# https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+REST+API+Reference

require 'logger'
require 'uri'

require 'levels_beyond/reach_engine/api/http_handler'

module LevelsBeyond

  module ReachEngine

    class API

      attr_accessor :logger, :http

      DEFAULT_BASE_PATH = '/reachengine/api/v1/'

      DEFAULT_FETCH_INDEX = 0
      DEFAULT_FETCH_LIMIT = 50

      DEFAULT_SERVER_PORT = 8080

      API_METHOD_PARAMETERS = { }

      def initialize(args = { })
        initialize_logger(args)

        args[:server_port] ||= DEFAULT_SERVER_PORT
        args[:api_base_path] ||= DEFAULT_BASE_PATH

        initialize_http_handler(args)
      end

      def initialize_logger(args = { })
        @logger = args[:logger] ||= Logger.new(STDERR)
      end

      def cached_method_parameters
        @cached_method_parameters ||= { }
      end

      # Sets the AdobeAnywhere connection information.
      # @see HTTPHandler#new
      def initialize_http_handler(args = {})
        @http = HTTPHandler.new(args)
        logger.debug { "Connection Set: #{http.to_s}" }
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
        parameter_names_normalized = parameter_names.is_a?(Hash) ? parameter_names : Hash[[*parameter_names].map { |param_name| [ param_name.to_s.gsub('_', '').downcase, param_name ] } ]
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

        [*parameters].each do |param|
          if param.is_a?(Hash)
            parameter_name = param[:name]
            defaults[parameter_name] = param[:default_value] if param.has_key?(:default_value)
            required_parameters[parameter_name] = param if param[:required]
          else
            parameter_name = param
          end
          parameter_names << parameter_name
        end

        logger.debug { "Processing Parameter(s): #{parameter_names.inspect}" }
        arguments_out = defaults.merge(filter_arguments(arguments, parameter_names, options))
        missing_required_parameters = required_parameters.keys - arguments_out.keys
        raise ArgumentError, "Missing Required Parameter(s): #{missing_required_parameters.join(', ')}" unless missing_required_parameters.empty?
        return arguments_out
      end

      # Looks up a methods parameters and matches arguments to those parameters
      #
      # @param [Symbol] method_name
      # @param [Hash] arguments The arguments being passed into the method
      # @param [Hash] options
      def process_method_parameters(method_name, arguments, options = { })
        parameters = api_method_parameters(method_name)
        process_parameters(parameters, arguments, options)
      end

      # @param [Hash] params Parameters to merge into
      # @return [Hash]
      def merge_additional_parameters(params, add_params, args, options = { })
        params.merge(process_parameters(add_params, args, options))
      end

      def api_method_parameters(method_name)
        #cached_method_parameters[method_name] ||= API_METHOD_PARAMETERS[method_name]
        API_METHOD_PARAMETERS[method_name]
      end

      # @!group API Methods

      # The Asset Search method uses a search term, as well as optional parameters, to find assets within the Reach
      # Engine Studio. The method returns a list of assets that matches the parameters provided, if any. If no search
      # term or other parameters are specified, the response contains up to 50 assets. More assets can be returned with
      # additional Find Assets requests using the FetchIndex parameter.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Assets
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
      def asset_find(args = { })
        query = process_method_parameters(__method__, args)
        #http.get('asset', query)
        http.get_paginated('asset', query)
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
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Asset+Details
      #
      # @param [String|Hash] asset_id The id of the asset to get the detail of
      # @return [Hash]
      # {
      #    "id": "417e5893-46d7-457b-b1a1-b5f316d4540e",
      #    "name": "Mickey is Awesome.mov",
      #    "contents": [
      #        {
      #            "id": "a20933dd-de29-491e-b62d-773a612efaa1",
      #            "name": "Episode Test 2.mov",
      #            "contentType": "VIDEO",
      #            "contentUses": [
      #                "MEZZANINE",
      #                "SOURCE"
      #            ],
      #            "mediaInfo": {
      #                "audioCodec": "40",
      #                "audioChannelCount": "2",
      #                "width": "1280",
      #                "aspectRatio": "16:9",
      #                "dropFrame": false,
      #                "startTime": "0.0",
      #                "duration": "140.0",
      #                "height": "720",
      #                "audioLanguage": "en",
      #                "bitrateKbs": "4957892.0",
      #                "startTimecode": "00:00:00:00",
      #                "frameRate": "24.0",
      #                "videoCodec": "avc1",
      #                "mimeType": "video/quicktime",
      #                "audioBitrate": "128000"
      #            }
      #        },
      #        {
      #            "id": "76f4cfa3-a908-4e5b-a357-7408d973b85e",
      #            "name": "Mickey_is_Awesome.mp4",
      #            "contentType": "VIDEO",
      #            "contentUses": [
      #                "PROXY"
      #            ],
      #            "mediaInfo": {
      #                "audioCodec": "40",
      #                "audioChannelCount": "2",
      #                "width": "854",
      #                "aspectRatio": "16:9",
      #                "dropFrame": false,
      #                "startTime": "-0.041999999433755875",
      #                "duration": "140.00799560546875",
      #                "height": "480",
      #                "audioLanguage": "en",
      #                "bitrateKbs": "996977.0",
      #                "startTimecode": "00:00:00:-1",
      #                "frameRate": "24.0",
      #                "videoCodec": "avc1",
      #                "mimeType": "video/mp4",
      #                "audioBitrate": "128054"
      #            }
      #        },
      #        {
      #            "id": "3b0d85ec-fab1-46b7-900e-f7463b4133bf",
      #            "name": "Mickey_is_Awesome.mov",
      #            "contentType": "VIDEO",
      #            "contentUses": [
      #                "THUMBNAIL_VIDEO"
      #            ],
      #            "mediaInfo": {
      #                "startTime": "0.0",
      #                "duration": "140.0",
      #                "height": "144",
      #                "startTimecode": "00:00:00:00",
      #                "bitrateKbs": "83914.0",
      #                "width": "256",
      #                "aspectRatio": "16:9",
      #                "frameRate": "1.0",
      #                "videoCodec": "jpeg",
      #                "dropFrame": false,
      #                "mimeType": "video/quicktime"
      #            }
      #        },
      #        {
      #            "id": "8ec294e7-cfd2-4941-967a-8efa52fae86c",
      #            "name": "Mickey_is_Awesome.jpg",
      #            "contentType": "IMAGE",
      #            "contentUses": [
      #                "THUMBNAIL"
      #            ],
      #            "mediaInfo": {
      #                "height": "144",
      #                "width": "256",
      #                "mimeType": "image/jpeg"
      #            }
      #        }
      #    ]
      # }
      def asset_detail(asset_id)
        asset_id = process_method_parameters(__method__, asset_id)[:asset_id] if asset_id.is_a?(Hash)

        http.get("asset/#{asset_id}")
      end
      API_METHOD_PARAMETERS[:asset_detail] = [ { :name => :asset_id, :required => true } ]

      # The Find Timelines method uses a search term to find timelines within the Reach Engine Studio. The method 
      # returns a list of timelines that matches the parameters provided, if any. If no search term or other parameters 
      # are specified, the response contains up to 50 timelines. More timelines can be returned with additional Find 
      # Timelines requests using the FetchIndex parameter.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Timelines
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
      def timeline_find(args = { })
        query = process_method_parameters(__method__, args)
        http.get('timeline', query)
      end
      alias :timelines :timeline_find
      alias :timeline_search :timeline_find
      API_METHOD_PARAMETERS[:timeline_find] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
        :search,
      ]

      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Timeline+Detail
      def timeline_detail(timeline_id)
        if timeline_id.is_a?(Hash)
          timeline_id = process_parameters([ { :name => :timeline_id, :required => true } ], timeline_id)[:timeline_id]
        end

        http.get("timeline/#{timeline_id}")
      end

      # The Timeline Clips returns information about clips associated with that timeline ID, if any are present.
      #
      # If the Timeline Detail method request included whether the timeline had a clip (via the timeline resource in
      # the response), you can use the Timeline Clips method.
      #
      # The response contains information about the timeline clip, including the clip ID, duration, creation date, and
      # start and end offset.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Timeline+Clips
      #
      # @return [<Hash>]
      # [
      #     {
      #         "id": "5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF",
      #         "timelineId": "1021",
      #         "name": "cool clip",
      #         "created": "2013-04-05T20:40:30.566+0000",
      #         "duration": "10",
      #         "startOffset": "14.019",
      #         "endOffset": "24.019",
      #         "metadata": {
      #         "categories": [],
      #         }
      #     }
      # ]
      def timeline_clips(timeline_id)
        if timeline_id.is_a?(Hash)
          timeline_id = process_parameters([ { :name => :timeline_id, :required => true } ], timeline_id)[:timeline_id]
        end

        http.get("timeline/#{timeline_id}/clips")
      end

      # The Find Clips method uses a search term, as well as optional parameters, to find clips within the Reach Engine
      # Studio.
      #
      # The method returns a list of clips that matches the search term or parameters provided in the request. If no
      # search term is sent in the request, the response will contain all clips within the Reach Engine Studio up to
      # the default limit of 50 results.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Clips
      #
      # @param [Hash] args
      # @option args [String] :search The term to match against.  Search terms are sent through a search engine, and
      # search all text in a document. Search supports partial words and similar words, but not wild cards. If no
      # parameter is offered, all assets are returned up to the default limit of 50.
      # @option args [Integer] :fetch_index Defines the start index of the results. E.g., "15" would start the results
      # on the fifteenth item returned. Used with fetchLimit for pagination controls.
      # @option args [Integer] :fetch_limit Defines the maximum number of results to return per page. If omitted, the
      # search is limited to 50 results.
      # @return [Hash]
      # {
      #    "fetchIndex": "0",
      #    "totalResultCount": "2",
      #    "thisResultCount": "2",
      #    "results": [
      #        {
      #            "id": "5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF",
      #            "timelineId": "9db86751-f9ae-4263-a84b-3cc89c795281",
      #            "name": "Donald 1",
      #            "created": "2013-04-05T20:40:30.566+0000",
      #            "duration": "10",
      #            "startOffset": "14.019",
      #            "endOffset": "24.019"
      #        },
      #        {
      #            "id": "5A77A9A8-AFCC-6AFF-057F-C9BBFFAA4B33",
      #            "timelineId": "e37e5ad6-0093-4a99-9188-4a652a517f0b",
      #            "name": "Donald 2",
      #            "created": "2013-04-02T07:52:53.930+0000",
      #            "duration": "10",
      #            "startOffset": "44.228",
      #            "endOffset": "54.228"
      #        }
      #    ]
      # }
      def clip_find(args = { })
        query = process_method_parameters(__method__, args)
        http.get('clip', query)
      end
      alias :clips :clip_find
      alias :clip_search :clip_find
      API_METHOD_PARAMETERS[:clip_find] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
        :search,
      ]

      # The Clip Details method is used with a clip ID to view clip details such as duration, start and end offset,
      # and geographic information. The clip ID can be found using the Find Clips method.
      #
      # @param [String] clip_id The UUID (universally unique identifier) of the clip
      # @return [Hash]
      # {
      #     "id": "5A77A9A8-AFCC-6AFF-057F-C9BBFFAA4B33",
      #     "timelineId": "e37e5ad6-0093-4a99-9188-4a652a517f0b",
      #     "name": "Donald 2",
      #     "created": "2013-04-02T07:52:53.930+0000",
      #     "duration": "10",
      #     "startOffset": "44.228",
      #     "endOffset": "54.228",
      #     "metadata": {
      #         "categories": [
      #             "Ready For Edit"
      #         ],
      #         "status": "Draft",
      #         "state": "Alabama",
      #         "country": "USA",
      #         "city": "Huntsville"
      #     }
      # }
      #
      # In the Response Sample:
      #   The metadata fields, including status, are purely for example purposes.
      #   Categories are a Reach Engine concept used to limit visibility and metadata field applicability.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Clip+Detail
      def clip_detail(clip_id)
        clip_id = process_method_parameters(__method__, clip_id)[:clip_id] if clip_id.is_a?(Hash)
        http.get("clip/#{clip_id}")
      end
      API_METHOD_PARAMETERS[:clip_detail] = [
        { :name => :clip_id, :required => true }
      ]

      # The Find Collections method uses a search term to find collections within the Reach Engine Studio.
      #
      # If no search term or other parameters are provided, the response contains up to 50 collections.
      # More collections can be returned with additional Find Collections requests using the Fetch Index parameter.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Collections
      #
      # @param [Hash] args
      # @option args [String] :search
      # @option args [Integer] :fetch_index
      # @option args [Integer] :fetch_limit
      # @return [Hash]
      def collection_find(args = { })
        query = process_method_parameters(__method__, args)
        http.get('collection', query)
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
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Collection+Detail
      #
      # @param [String] collection_id The UUID (universally unique identifier) of the collection
      # @return [Hash]
      def collection_detail(collection_id)
        collection_id = process_method_parameters(__method__, collection_id)[:collection_id] if collection_id.is_a?(Hash)
        http.get("collection/#{collection_id}")
      end
      API_METHOD_PARAMETERS[:collection_detail] = [
        { :name => :collection_id, :required => true },
      ]


      # Creates a new collection, ready for member insertion, using the collection name provided in the request. After
      # a new collection is created, use the Add Collection Member methods to add member items.
      #
      # Note: For collection naming conventions, spaces and special characters are allowed, as well as duplicate names.
      # What differentiates same-name collections is the meta data (image, timestamp, etc.) and the reference ID.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Create+Collections
      #
      # @param [String] name The name of the Collection to be created.
      # @param [Hash] metadata A hash with metadata key/value pairs for this collection.
      # @return [Hash]
      # {
      #      "id": "f576b779-07cb-4f52-9e59-695ddbc2eb1d",
      #      "name": "Disney",
      #      "metadata": {
      #         "categories": [],
      #         "mainCharacter": "Mickey Mouse"
      #     }
      # }
      def collection_create(name, metadata = { })
        if name.is_a?(Hash)
          data = process_method_parameters(__method__, name)
        else
          data = { :name => name }
          data[:metadata] = metadata if metadata.respond_to?(:empty?) and !metadata.empty?
        end
        http.post_json('collection', data)
      end
      API_METHOD_PARAMETERS[:collection_detail] = [
        { :name => :collection_id, :required => true },
        { :name => :metadata }
      ]

      # The Collection Member Add method sends a collection ID and specifies the asset type and ID to add to the
      # collection. IDs are automatically created when a video is uploaded. Only one collection member can be
      # added in a single request.
      #
      # The Collection Member Add response contains information about the clip, including the clip name (provided by
      # the user when the clip was created) and clip ID. The response displays all associated members in the response;
      # therefore, if collection members have been added during a prior request, the existing collection members, in
      # addition to the newly added collection member, will all display in the response.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Add+Collection+Member                                                                                                                                                                                                                                                                                                                                                                                                                   #
      #
      # @param [String] collection_id The Collection UUID (universally unique identifier).
      # @param [String] member_class The type of the asset to be added to the Collection.
      #                              Valid values include "AssetMaster", "Timeline", and "Clip".
      # @param [String] member_id The UUID (universally unique identifier) of the asset.
      # @return [Array<Hash>]
      # [
      #      {
      #          "name": "Donald 1",
      #          "archived": false,
      #          "class": "Clip",
      #          "id": "5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF"
      #      },
      #      {
      #          "name": "Test Clip",
      #          "archived": false,
      #          "class": "Clip",
      #          "id": "e8d497db-4f14-483a-ab1b-9db440e2f729"
      #      }
      # ]
      def collection_member_add(collection_id, member_class = nil, member_id = nil)
        if collection_id.is_a?(Hash)
          data = process_method_parameters(__method__, collection_id)
          collection_id = data.delete(:collection_id)
        else
          data = {
            :class => member_class,
            :id => member_id
          }
        end

        http.post_json("collection/#{collection_id}/members", data)
      end
      API_METHOD_PARAMETERS[:collection_member_add] = [
        { :name => :collection_id,  :required => true },
        { :name => :member_class,   :required => true },
        { :name => :member_id,      :required => true },
      ]


      # The Collection Member Remove method sends a collection ID and specifies the member class and member ID to
      # remove from the collection. To determine the member class and ID, use the Collection Member method. No more
      # than one member can be removed in a single request.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Remove+Collection+Member
      #
      # @param [String] collection_id The Collection UUID (universally unique identifier).
      # @param [String] member_class The class of the member to remove. This value should match the "class" property in
      # the member JSON structure from a query result.
      # @param [String] member_id The UUID of the member to remove. This value should match the "id" property in the
      # member JSON structure from a query result.
      # @return [Array<Hash>]
      def collection_member_remove(collection_id, member_class = nil, member_id = nil)
        if collection_id.is_a?(Hash)
          data = process_method_parameters(__method__, collection_id)
          collection_id = data[:collection_id]
          member_class = data[:member_class]
          member_id = data[:member_id]
        end

        http.delete("collection/#{collection_id}/members/#{member_class}/#{member_id}")
      end
      API_METHOD_PARAMETERS[:collection_member_remove] = [
        { :name => :collection_id,  :required => true },
        { :name => :member_class,   :required => true },
        { :name => :member_id,      :required => true },
      ]

      # A collection member is an asset within a collection. An asset collection contains collection members, and
      # assets can belong to more than one collection. However, it is not possible to nest collections (you cannot have
      # a collection of collections).
      #
      # @param [String] collection_id
      # @return [Array<Hash>]
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Find+Collection+Members
      def collection_member_find(collection_id)
        if collection_id.is_a?(Hash)
          collection_id = process_method_parameters(__method__, collection_id)[:collection_id]
        end

        http.get("collection/#{collection_id}/members")
      end
      alias :collection_members :collection_member_find
      alias :collection_member_search :collection_member_find
      API_METHOD_PARAMETERS[:collection_member_find] = [
        { :name => :collection_id,  :required => true },
      ]

      # The Query Workflows method returns a list of workflows.
      #
      # You can optionally narrow results by specifying the class type against which the workflow operates.
      # If no subject class or other parameters are specified, the response contains up to 50 workflows. More workflows
      # can be returned with additional Query Workflows requests using the fetchIndex parameter.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Query+Workflows
      #
      # @param [Hash] args
      # @option args [String] :subject_class The type of Reach Engine entity that this workflow operates against.
      # Valid values include Asset, Timeline, Clip, Project, and AssetCollection.
      # @option args [Integer] :fetch_index Defines the start index of the results. E.g., "15" would start the results
      # on the fifteenth item returned. Used with fetchLimit for pagination controls.
      # @option args [Integer] :fetch_limit Defines the maximum number of results to return per page. If omitted, the
      # search is limited to 50 results.
      # @return [Hash]
      #   {
      #      "fetchIndex": "0",
      #      "totalResultCount": "5",
      #      "thisResultCount": "5",
      #      "results": [
      #          {
      #              "id": "_ingestAssetToCollection",
      #              "name": "Ingest Asset to Collection",
      #              "subjectClass": "AssetCollection",
      #              "enabled": true
      #          },
      #          {
      #              "id": "_exportCollectionToNLE",
      #              "name": "Export Collection to NLE",
      #              "subjectClass": "AssetCollection",
      #              "enabled": true
      #          },
      #          {
      #              "id": "_exportBinProxiesToNLE",
      #              "name": "Export Collection to NLE",
      #              "subjectClass": "AssetCollection",
      #              "enabled": true
      #          },
      #          {
      #              "id": "_enableCollectionWatchFolder",
      #              "name": "Enable Collection Watch Folder",
      #              "subjectClass": "AssetCollection",
      #              "enabled": true
      #          },
      #          {
      #              "id": "_archiveCollectionContents",
      #              "name": "Archive Collection Contents",
      #              "subjectClass": "AssetCollection",
      #              "enabled": true
      #          }
      #      ]
      #   }
      def workflow_query(args = { })
        query = process_method_parameters(__method__, args)
        http.get('workflow', query)
      end
      alias :workflows :workflow_query
      API_METHOD_PARAMETERS[:workflow_query] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
        :subject_class,
      ]

      # The Workflow Detail method sends a workflow ID and returns details about the workflow.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Workflow+Detail
      #
      # @param [String] workflow_id
      # @return [Hash]
      # {
      #   "id": "_archiveCollectionContents",
      #   "name": "Archive Collection Contents",
      #   "subjectClass": "AssetCollection",
      #   "enabled": true,
      #   "contextDataDefs": [
      #     {
      #        "name": "targetFilename",
      #        "type": "String",
      #        "required": false,
      #        "multiple": false
      #     },
      #     {
      #        "name": "targetDirectory",
      #        "type": "Directory",
      #        "required": false,
      #        "multiple": false
      #     }
      #   ]
      # }
      def workflow_detail(workflow_id)
        if workflow_id.is_a?(Hash)
          workflow_id = process_method_parameters(__method__, workflow_id)[:workflow_id]
        end
        http.get("workflow/#{workflow_id}")
      end
      API_METHOD_PARAMETERS[:workflow_detail] = [
        { :name => :workflow_id, :required => true }
      ]

      # The Start Workflow Execution method begins the workflow identified by the workflow ID sent in the request.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Start+Workflow
      #
      # @param [String] subject_id_or_workflow_id One of the following IDs is required in the request:
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
      def workflow_start(subject_id_or_workflow_id, args = { })
        if subject_id_or_workflow_id.is_a?(Hash)
          args.merge!(subject_id_or_workflow_id)
          subject_id_or_workflow_id = nil
        end
        data = process_method_parameters(__method__, args)
        subject_id_or_workflow_id ||= data.delete(:subject_id_or_workflow_id)

        http.post_json("workflow/#{subject_id_or_workflow_id}/start", data)
      end
      alias :workflow_execution_start :workflow_start
      API_METHOD_PARAMETERS[:workflow_start] = [
        { :name => :subject_id_or_workflow_id, :alias => [ :subject_id, :workflow_id, :id ],
          #:required => true
        },
        { :name => :context_data }
      ]

      # @param [String] subject_id_or_workflow_id One of the following IDs is required in the request:
      #                      subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #                      workflowID, which can be found in a Query Workflow response.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Get+Workflow+Execution+Status
      def workflow_execution_status(subject_id_or_workflow_id, args = { })
        query = process_method_parameters(__method__, args)
        http.get("workflow/execution/#{subject_id_or_workflow_id}", query)
      end
      API_METHOD_PARAMETERS[:workflow_execution_status] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
        #{ :name => :subject_id_or_workflow_id, :alias => [ :subject_id, :workflow_id, :id ] }, #, :required => true },
        :subject_id,
      ]

      # @param [String] subject_id_or_workflow_id One of the following IDs is required in the request:
      #   subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #   workflowID, which can be found in a Query Workflow response.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Stop+Workflow+Execution
      def workflow_execution_stop(subject_id_or_workflow_id)
        http.post("workflow/#{subject_id_or_workflow_id}/stop")
      end
      API_METHOD_PARAMETERS[:workflow_execution_stop] = [
        { :name => :subject_id_or_workflow_id, :alias => [ :subject_id, :workflow_id, :id ], :required => true }
      ]

      # @param [String] id One of the following IDs is required in the request:
      #   subjectID, which is the workflow's subject UUID (universally unique identifier), or
      #   workflowID, which can be found in a Query Workflow response.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Resume+Workflow+Execution
      def workflow_execution_resume(subject_id_or_workflow_id)
        http.post("workflow/#{subject_id_or_workflow_id}/resume")
      end
      API_METHOD_PARAMETERS[:workflow_execution_resume] = [
        { :name => :subject_id_or_workflow_id, :alias => [ :subject_id, :workflow_id, :id ], :required => true }
      ]

      # The Get Watchfolder method returns a list of watchfolders.
      #
      # The details provided in the response include the watchfolder name, location, whether the watchfolder is
      # enabled or disabled, and poll interval seconds.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Get+Watchfolders
      #
      # @return [Hash]
      # {
      #     "fetchIndex": "0",
      #     "totalResultCount": "2",
      #     "thisResultCount": "2",
      #     "results": [
      #         {
      #             "name": "imageSequence",
      #             "enabled": true,
      #             "watchFolder": "/Users/davelamy/Development/hotfolder/imageSequence",
      #             "maxConcurrent": "1",
      #             "deleteOnSuccess": false,
      #             "processFolders": true,
      #             "pollIntervalSeconds": "5",
      #             "workflowKey": "_ingestImageSequenceFolder",
      #             "fileDataDef": "imageSequenceDir",
      #             "requireFileLock": false,
      #             "contextData": {
      #                 "mezzanineTemplate": "FFmpeg-Prores"
      #             },
      #             "_id": "517af85f9436565b3964da0d"
      #         },
      #         {
      #             "name": "API Watchfolder",
      #             "enabled": false,
      #             "watchFolder": "/Users/davelamy/Development/hotfolder/APITest",
      #             "maxConcurrent": "3",
      #             "deleteOnSuccess": false,
      #             "processFolders": false,
      #             "pollIntervalSeconds": "5",
      #             "workflowKey": "ingestAssetToCollection",
      #             "fileDataDef": "fileToIngest",
      #             "requireFileLock": false,
      #             "contextData": {
      #                 "targetCollection": "[AssetCollection.200]"
      #             },
      #             "_id": "519292bc11b0fa0a37eb9600"
      #         }
      #     ]
      # }
      #
      # @note The API Documentation does not mention the fetchIndex and fetchLimit parameters other than in the
      #   response so it is being assumed that they are available. 2014-04-17
      def watch_folder_find(args = { })
        http.get('workflow/watchfolder')
      end
      alias :watch_folders :watch_folder_find
      alias :watch_folder_search :watch_folder_find
      API_METHOD_PARAMETERS[:watch_folder_find] = [
        { :name => :fetch_index, :default_value => DEFAULT_FETCH_INDEX },
        { :name => :fetch_limit, :default_value => DEFAULT_FETCH_LIMIT },
      ]

      # Creates a new watchfolder at the configured path.
      #
      # By default, watchfolders are created but not enabled.
      # To enable a watchfolder, either set the "enabled" property when creating, or call the /enable method later.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Create+Watchfolder
      #
      # @param [Hash] args
      # @option args [String] :name The name of the watchfolder to be created.
      # @option args [String] :watch_folder The file system path to the new watchfolder.
      # @option args [String] :workflow_key The ID of the workflow to call when a file is placed into the watchfolder.
      # @option args [String] :file_data_def The file that is detected in the watchfolder must be assigned to a data
      #   def in the workflow defined by workflowKey. This value must match a File data def in the target workflow.
      # @option args [String] :subject
      # @option args [Boolean] :enabled Whether or not the watchfolder is enabled. Defaults to "false".
      # @option args [Boolean] :delete_on_success Whether to delete the file in the watchfolder after processing.
      #   Defaults is "false".
      # @option args [Integer] :max_concurrent The maximum number of files to process at a time. Defaults to 1.
      # @option args [Hash] :context_data Optionally pass other context data into the workflow defined by workflowKey
      #   when a file is to be processed by the workflow. This hash's keys should each be the name of a data def in the
      #   workflow, and the value being a valid value for the data def's type
      #   (i.e., if type is "Integer" value must be a valid number).
      def watch_folder_create(args = { })
        data = process_method_parameters(__method__, args)
        return http.post_json('workflow/watchfolder', data)
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

      # The Enable Watchfolder method enables a watchfolder that is disabled.
      #
      # Enabling or disabling a watchfolder determines whether or not adding a file to the watchfolder triggers a
      # workflow. Therefore, if a watchfolder is enabled, and a file is then added to a watchfolder, a workflow is
      # automatically triggered.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Enable+Watchfolder
      #
      # @param [String] watch_folder_id The id of the watch folder
      # @return [Hash]
      def watch_folder_enable(watch_folder_id)
        if watch_folder_id.is_a?(Hash)
          watch_folder_id = process_method_parameters(__method__, watch_folder_id)[:watch_folder_id]
        end

        http.post("workflow/watchfolder/#{watch_folder_id}/enable")
      end
      API_METHOD_PARAMETERS[:watch_folder_enable] = [
        { :name => :watch_folder_id,   :required => true },
      ]

      # The Disable Watchfolder method disables an enabled watchfolder.
      #
      # When a watchfolder is disabled, it  essentially turns the folder “off” so that it's no longer valid for a
      # workflow. For example, a watchfolder can be disabled for content reorganization or when activating a new drive
      # and setting up a new watchfolder. A watchfolder cannot be moved, only deleted or created.
      #
      # @see https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+Enable+Watchfolder
      #
      # @param [String] watch_folder_id The id of the watch folder
      # @return [Hash]
      def watch_folder_disable(watch_folder_id)
        if watch_folder_id.is_a?(Hash)
          watch_folder_id = process_method_parameters(__method__, watch_folder_id)[:watch_folder_id]
        end
        http.post("workflow/watchfolder/#{watch_folder_id}/disable")
      end
      API_METHOD_PARAMETERS[:watch_folder_disable] = [
        { :name => :watch_folder_id,   :required => true },
      ]

      # The Reach Engine Query Language (RQL) can be used by both end users and developers building apps on the Reach
      # Engine Platform. The implementation of RQL is designed to be loosely coupled with the underlying search engine,
      # so additional implementations can be constructed for other search engines or databases.
      #
      # When performing a RQL query, specify the name of the property you would like to search against.
      #
      # Picklist values can be supplied by label or value.
      #
      # More traditional-looking upper-case SQL is supported. Both of the following syntax are supported:
      #
      #    name like 'cook'
      #    name LIKE 'cook'
      #
      # Important! Some searches are case sensitive and only find exact matches to the value entered.
      #
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # |     Search Type     |                          Description                           |                                   Example                                   |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Equals              | Returns all values that exactly match the value entered.       | name = 'cook'                                                               |  |
      # |                     |                                                                | Finds all values where name equals cook. 										 				       |  |
      # |											|                                                                | The following results would not be returned because                         |  |
      # |                     |                                                                | they are not an exact match: cook1 or Cook.                                 |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Not equals          | Returns all values not matching the value entered.             | name != 'cook'                                                              |  |
      # |                     |                                                                | Finds all values where name does not equal cook.                            |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Offsets and         | Pagination is controlled with the offset and size keywords.    | name = 'cook' offset 4 size 3                                               |  |
      # | pagination          |                                                                | Returns results in groups of 3, 4 results into the result set.              |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Like                | Returns values that contain the value entered.                 | name like 'ook'                                                             |  |
      # |                     |                                                                | Performs a “contains” query on the field specified.                         |  |
      # |									    |                                                           		 | Therefore, values such as looking and booking are returned. 								 |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Not like            | Returns values that do not contain the value entered.          | name not like 'ook'                                                         |  |
      # |									    |																														     | Performs a 'does not contain' query on the field specified.                 |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | In                  | Returns all results that contain the values submitted.         | myList in ('one', 'two', 'three') 																			     |  |
      # |									    |																														     | Performs a query where 'myList' contains values one, two, or three.         |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Not in              | Returns all results that do not contain the value submitted.   | myList not in ('one', 'two', 'three')                                       |  |
      # |									    |																														     | Performs a query where 'myList' does not contain values one, two, or three. |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Between             | Returns values between two dates, integers, or numbers.        | myDate between '2013/10/01' and '2013/10/05'                                |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Is null             | Returns all fields that are blank or null.                     | aField is null                                                              |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Greater Than /      | 'greater than' and 'greater than or equals' are                | price gt ‘12.99' dateUpdated gte '2012-10-01’                               |  |
      # | Greater Than Equals | represented with the 'gt' and 'gte' symbols.                   |                                                                             |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Less Than /         | 'less than' and 'less than or equals' are                      | price lt 12.99 dateUpdated lte '2012-10-01'                                 |  |
      # | Less Than Equals    | represented with the 'lt' and 'lte' symbols.                   |                                                                             |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Sorts               | Sorts by a field. Multiple sorts are allowed and are separated | name = 'cook' order by dateUpdated asc                                      |  |
      # |                     | by a comma.                                                    | name = 'cook' order by dateUpdated asc, name desc                           |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      # | Ands and Ors        | Used to group expressions.                                     | (name = 'Bruce Wayne' or systemKeywords like 'batman') and cowled = 'true'  |  |
      # |                     | Order of operations gives precedence to and, but order can     |                                                                             |  |
      # |                     | be controlled with parentheses.                                |                                                                             |  |
      # +---------------------+----------------------------------------------------------------+-----------------------------------------------------------------------------+--+
      #
      # @param [Hash] args
      # @option args [String] :rql The RQL statement
      # @option args [String|Array<String>] :types An array of types or a string consisting of a pipe-separated list of
      # types you would like to search against.
      def search(args = { })
        types = args[:types]
        rql = args[:rql] || args[:query]

        query = {}
        query[:types] = [*types].join('|') if types
        query[:rql] = rql if rql
        http.get('search', query)
      end
      API_METHOD_PARAMETERS[:search] = [ :types, :rql ]

      # @!endgroup

    end

  end

end
