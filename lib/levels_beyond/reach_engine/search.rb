# https://levelsbeyond.atlassian.net/wiki/display/DOC/1.3+REST+API+Reference

require 'logger'
require 'uri'

require 'levels_beyond/reach_engine/search/http_handler'

module LevelsBeyond

  module ReachEngine

    class Elasticsearch

      attr_accessor :logger, :client

      def initialize(args = { })
        @logger = args[:logger] ||= Logger.new(STDOUT)
        @client = args[:client]
      end

      def snake_case_to_lower_camel_case(string)
        string.gsub(/(?:_)(\w)/) { $1.upcase }
      end

      def hash_to_query(hash)
        return URI.encode(hash.map{|k,v| "#{snake_case_to_lower_camel_case(k.to_s)}=#{v}"}.join('&')) if hash.is_a?(Hash)
      end

      def mapping(index = '_all', type = nil)
        path = [ index ]
        path << type if type
        path << :_mapping
        client.get(path.join('/'))
      end

      def build_search_path(args)
        path = [ ]

        index = args[:index]
        if index
          logger.debug { "Search Path Index: #{index}" }
          path << index

          type = args[:type]
          if type
            logger.debug { "Search Path Type: #{type}" }
            path << type

            # We want to shift id to the path if we are doing a simple id => 213 type search
            args[:id] ||= begin
              query = args[:query] || { }

              id = query[:id]
              if id
                id = query.delete(:id) { } unless id.is_a?(Hash)
              else
                term = query[:term] || { }
                logger.debug { "Term: #{term.inspect}" }
                id = term[:id]
                id = term.delete(:id) if id and !id.is_a?(Hash)
              end
              id
            end

            #id = args[:id]
            logger.debug { "Search Path ID: #{id}" } and path << id if id
          end
        end

        path << :_search unless id
        path.join('/')
      end

      def build_search_uri_query(args)
        query = args[:query] || { }
        logger.debug { "Building Search URI Query: #{query.inspect}"}
        term_query = query.delete(:term) || { }
        query_string = build_search_uri_query_term(term_query)
        logger.debug { "Query String: #{query_string.class.name} #{query_string}" }
        query[:q] = query_string if query_string.respond_to?(:empty?) and !query_string.empty?
        logger.debug { "Query: #{query.inspect}" }
        query
      end

      def build_search_uri_query_term(term = { }, options = { })
        term.map { |k,v| "#{snake_case_to_lower_camel_case(k.to_s)}:#{v}" }.join(' ')
      end

      def build_search_uri_request_path(args = { })
        path = build_search_path(args)
        query = args[:query] || { }

        term_query = query.delete(:term) || { }
        query_string = build_search_uri_query_term(term_query)

        query[:q] = query_string if query_string.respond_to?(:empty) and !query_string.empty?
        "#{path}#{ query.respond_to?(:empty?) and !query.empty? ? "?#{query}" : '' }"
      end

      # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/0.90/search-uri-request.html
      def search_using_request_uri(args = { })
        path = build_search_path(args)
        query = build_search_uri_query(args)
        client.get(path, query)
      end

      # http://www.elasticsearch.org/guide/en/elasticsearch/reference/0.90/search-request-body.html
      def search_using_request_body(args = { })

      end

      def search(args)
        search_using_request_uri(args)
      end

    end

    class Search


      attr_accessor :logger, :http, :elasticsearch

      DEFAULT_FETCH_INDEX = 0
      DEFAULT_FETCH_LIMIT = 50

      DEFAULT_SERVER_ADDRESS = 'localhost'
      DEFAULT_SERVER_PORT = 9200

      API_METHOD_PARAMETERS = { }

      def initialize(args = { })
        initialize_logger(args)

        initialize_http_handler(args)
        initialize_elasticsearch(args)
      end

      def initialize_logger(args = { })
        @logger = args[:logger] ||= Logger.new(STDERR)
        log_level = args[:log_level]
        @logger.level = log_level if log_level
      end

      # Sets the AdobeAnywhere connection information.
      # @see HTTPHandler#new
      def initialize_http_handler(args = {})
        args.dup
        args[:search_server_address] ||= args[:server_address] || DEFAULT_SERVER_ADDRESS
        args[:search_server_port] ||= DEFAULT_SERVER_PORT

        @http = HTTPHandler.new(args)
        logger.debug { "Connection Set: #{http.to_s}" }
      end

      def initialize_elasticsearch(args)

        args[:client] ||= http
        logger.debug { "Search Args: #{PP.pp(args, '')}"}
        @elasticsearch = Elasticsearch.new(args)
      end

      def search(args = { }, options = { })

        if options.fetch(:convert_query_to_term_query, true)
          query = args[:query]
          args[:query] = { :term => query } if query
        end

        _args = {
          :index => 'reach'
        }
        _args.merge!(args)
        elasticsearch.search(_args)
      end

      def parse_get_by_response(response)
        if response.has_key?('exists')
          source = response['_source']
          return false unless source
          #source['id'] ||= response['_id']
          return source
        end

        hits = response['hits']
        return false unless hits
        return hits['hits']
      end


      ##################################################################################################################

      # Indexed Types
      #
      # "ImageAssetMaster"
      # "AudioAssetMaster"
      # "AssetCollection"
      # "Project"
      # "DocumentAssetMaster"
      # "AssetMaster"
      # "Timeline"
      # "Clip"

      def asset_collections(query = { })
        search( :type => 'AssetCollection', :query => query )
      end

      def asset_masters(query = { }, options = { })
        search( { :type => 'AssetMaster', :query => query }, options )
      end

      def audio_asset_masters(query = { }, options = { })
        search( { :type => 'AudioAssetMaster', :query => query }, options )
      end

      def clips(query = { }, options = { })
        search( { :type => 'Clip', :query => query }, options )
      end

      def document_asset_masters(query = { }, options = { })
        search( { :type => 'DocumentAssetMaster', :query => query }, options )
      end

      def image_asset_masters(query = { }, options = { })
        search( { :type => 'ImageAssetMaster', :query => query }, options )
      end

      def projects(query = { }, options = { })
        search( { :type => 'Project', :query => query }, options )
      end

      def timelines(query = { }, options = { })
        search( { :type => 'Timeline', :query => query }, options )
      end


      def clip_by_name(name)
        search( :type => 'Clip')
      end


      def timeline_by(field, value)
        response = timelines(field => value)
        parse_get_by_response(response)
      end

      def timeline_by_id(id)
        timeline_by(:id, id)
      end

      def timeline_by_name(name)
        timeline_by(:name, name)
      end


    end

  end

end

if $0 == __FILE__
require 'pp'
args = {
  :server_address => '10.42.1.70',
  :log_response_body => true,
  :log_pretty_print_body => true,

}
#search = LevelsBeyond::ReachEngine::Search.new(args)
# pp search.asset_collections
# pp search.timelines
# pp search.timelines(:id => 200)
# pp search.timeline_by_id(200)
#pp search.timeline_by_name('3df35a45025dfecad1b4b74670b914ce_proxy.mov')
end