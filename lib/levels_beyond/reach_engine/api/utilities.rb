require 'levels_beyond/reach_engine/api'
module LevelsBeyond

  module ReachEngine

    class API

      class Utilities < API

        class ArgumentsHandler

          def values
            @values ||= { }
          end

          def initialize(values, options = { })
            values.map { |k,v| [ k.to_s.sub('_', '').downcase, v ] }
          end

          def []=(key, value)
            k = key.to_s.sub('_', '').downcase
            @values[k] = value
          end

          def [](key)
            k = key.to_s.sub('_', '').downcase
            @values[k]
          end

        end

        DEFAULT_ASSET_INGEST_ANY_WORKFLOW_ID = '_anyAssetIngest'
        attr_accessor :default_asset_ingest_any_workflow_id

        def initialize(args = { })
          super(args)
          @default_asset_ingest_any_workflow_id = args[:default_asset_ingest_any_workflow_id] || DEFAULT_ASSET_INGEST_ANY_WORKFLOW_ID
        end

        def watch_folder_by_path(watch_folder_path)
          response = watch_folder_search
          watch_folders = response['results']
          watch_folders.each do |watch_folder|
            current_watch_folder_path = watch_folder['watchFolder']
            return watch_folder if current_watch_folder_path == watch_folder_path
          end
          nil
        end

        def enable_watch_folder_by_path(watch_folder_path)
          watch_folder = watch_folder_by_path(watch_folder_path)
          watch_folder_id = watch_folder['']
          watch_folder_enable(watch_folder_id)
        end

        def disable_watch_folder_by_path(args = { })
          watch_folder = watch_folder_by_path(watch_folder_path)
          watch_folder_id = watch_folder['']
          watch_folder_disable(watch_folder_id)
        end

        def search(args = { })
          # [4/11/14 4:03:49 PM] Nicholas Stokes:
          #   search-asset {"type":"video,project,image", {"name = 'LIKE'":"ubiquity", "SIZE": 100, "OFFSET": 0, "dataUpdated": "DESC"} }
          #   172.16.180.189:8080/reachengine/api/v1/search?types=|ImageAssetMaster|Project|Timeline|&rql=name LIKE 'ubiquity' SIZE 100 OFFSET 0 ORDER_BY dateUpdated DESC&apiKey=6c6f19c1-73d1-40f6-8ad9-64878ca5879c
          #   search-asset {"type":"video|project|image", {"name = 'LIKE'":"ubiquity", "SIZE": 100, "OFFSET": 0, "dataUpdated": "DESC"} }
          super(args)
        end
        alias :search_asset :search


        def asset_ingest_any(args = { })
          parameters = cached_method_parameters[__method__] ||= [
            { :name => :file_to_ingest, :required => true },
            #{ :name => :workflow_id,    :default => default_asset_ingest_any_workflow_id },
            :workflow_id
          ]
          _args = process_parameters(parameters, args.dup)

          workflow_id = _args.delete(:workflow_id) { default_asset_ingest_any_workflow_id }
          file_to_ingest = _args.delete(:file_to_ingest) { }

          raise ArgumentError, ':file_to_ingest is a required argument.' unless file_to_ingest

          workflow_start(workflow_id, { :context_data => { :file_to_ingest => file_to_ingest } }.merge(args))
        end
        alias :create_asset :asset_ingest_any

        def create_watch_folder_and_ingest_assets_into_collection(args = { })
          args[:workflow_key] ||= '_ingestAssetToCollection'
          args[:enabled] = args.fetch(:enabled, true)
          args[:delete_on_success] = args.fetch(:delete_on_success, false)
          watch_folder_create(args)
        end

      end

    end

  end

end