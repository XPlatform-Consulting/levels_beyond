require 'levels_beyond/reach_engine/api'
require 'levels_beyond/reach_engine/search'
module LevelsBeyond

  module ReachEngine

    class API

      class Utilities < API

        DEFAULT_ASSET_INGEST_ANY_WORKFLOW_ID = '_anyAssetIngest'

        attr_accessor :default_asset_ingest_any_workflow_id, :search_api

        def initialize(args = { })

          ## API DEFAULT OVERRIDES

          auto_paginate_response = args.fetch(:enable_auto_pagination, true)
          args[:enable_auto_pagination] = auto_paginate_response

          super(args)

          ## UTILITIES SPECIFIC

          @default_asset_ingest_any_workflow_id = args[:default_asset_ingest_any_workflow_id] || DEFAULT_ASSET_INGEST_ANY_WORKFLOW_ID
          @search_api = LevelsBeyond::ReachEngine::Search.new(args)

        end



        # @!group Asset Methods

        # Triggers an asset ingest
        #
        # @param [Hash] args
        # @option args [String] :file_to_ingest (REQUIRED) The path of the file to ingest.
        # @option args [String] :workflow_id (DEFAULT_ASSET_INGEST_ANY_WORKFLOW_ID)
        # @return [Hash]
        def asset_ingest_any(args = { })
          parameters = api_method_parameters(__method__)
          _args = process_parameters(parameters, args.dup)

          # workflow_name = _args[:workflow_name]
          # if workflow_name
          #   workflow = find_workflow_by_name
          # end
          workflow_id = _args.delete(:workflow_id) { default_asset_ingest_any_workflow_id }
          file_to_ingest = _args.delete(:file_to_ingest) { }

          raise ArgumentError, ':file_to_ingest is a required argument.' unless file_to_ingest

          context_data = _args[:context_data] || { }
          context_data[:file_to_ingest] = file_to_ingest
          _args[:context_data] = context_data

          workflow_execution_start(workflow_id, _args)
        end
        alias :asset_create :asset_ingest_any
        alias :create_asset :asset_ingest_any
        API_METHOD_PARAMETERS[:asset_ingest_any] = [
          { :name => :file_to_ingest, :required => true },
          :workflow_id,
          :workflow_name,
          :context_data
        ]

        # Triggers an asset ingest on all files in a folder
        #
        # @param [String] :folder_to_ingest (REQUIRED) The path of a folder (or file) to ingest.class
        # @option args [String] :workflow_id (DEFAULT_ASSET_INGEST_ANY_WORKFLOW_ID)
        # @return [<Hash>]
        def folder_asset_ingest(args = { })
          parameters = api_method_parameters(__method__)
          _args = process_parameters(parameters, args.dup)

          folder_to_ingest = _args.delete(:folder_to_ingest) { }

          raise ArgumentError, ':folder_to_ingest is a required argument.' unless folder_to_ingest

          folder_to_ingest = File.join(folder_to_ingest, '*') if File.directory?(folder_to_ingest)

          file_paths = Dir.glob(folder_to_ingest)

          file_paths.map { |file_path| asset_ingest_any( _args.merge( :file_to_ingest => file_path ) ) }
        end
        API_METHOD_PARAMETERS[:folder_asset_ingest] = [
          { :name => :folder_to_ingest, :required => true },
          :workflow_id,
          :workflow_name,
          :context_data
        ]

        alias :folder_asset_create :folder_asset_ingest

        alias :search_asset :search

        # @!endgroup


        # @!group Watch Folder Methods

        def watch_folder_by(criteria)
          response = watch_folder_find
          return response.find_first_match(criteria)
        end

        # @param [String] watch_folder_path The path of the watch folder.
        def watch_folder_by_path(watch_folder_path)
          # watch_folders = response['results']
          # watch_folders.each do |watch_folder|
          #   current_watch_folder_path = watch_folder['watchFolder']
          #   return watch_folder if current_watch_folder_path == watch_folder_path
          # end
          # nil
          watch_folder_by('watchFolder' => watch_folder_path)
        end

        def watch_folder_by_name(watch_folder_name)
          watch_folder_by('name' => watch_folder_name)
        end

        def enable_watch_folder_by_path(watch_folder_path)
          watch_folder = watch_folder_by_path(watch_folder_path)
          return false unless watch_folder
          watch_folder_id = watch_folder['_id']
          watch_folder_enable(watch_folder_id)
        end

        def disable_watch_folder_by_path(watch_folder_path)
          watch_folder = watch_folder_by_path(watch_folder_path)
          return false unless watch_folder
          watch_folder_id = watch_folder['_id']
          watch_folder_disable(watch_folder_id)
        end

        def create_watch_folder_and_ingest_assets_into_collection(args = { })
          args[:workflow_key] ||= '_ingestAssetToCollection'
          args[:enabled] = args.fetch(:enabled, true)
          args[:delete_on_success] = args.fetch(:delete_on_success, false)
          args[:file_data_def] ||= 'fileToIngest'
          watch_folder_create(args)
        end

        # @!endgroup

        # @!group Workflow Methods

        def workflow_detail(args = { })
          if args.is_a?(Hash)
            workflow_name = args.delete(:name)

          end
          super(args)
        end

        # @!endgroup Workflow Methods


      end

    end

  end

end