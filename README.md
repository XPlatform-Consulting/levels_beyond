LevelsBeyond
============

## Installation

Add this line to your application's Gemfile:

    gem 'levels_beyond'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install levels_beyond

Reach Engine API Executable [bin/reach_engine]
---------------------------

## Usage
    Usage: reach_engine [options] [method_name] [method_arguments]
        --reach-engine-server-address SERVERADDRESS
                                     The Reach Engine server address.
        --reach-engine-server-port SERVERPORT
                                     The Reach Engine server port.
        --api-key APIKEY             The API key to use when calling the api.
        --method-name METHODNAME     The name of the method to call.
        --method-arguments JSON      The a JSON string consisting of the arguments to pass to the method.
        --[no-]log-request-body      Determines if the request body is logged.
        --[no-]log-response-body     Determines if the response body is logged.
        --[no-]log-pretty-print-body Determines if the request and response bodies are pretty printed in the log output.
        --[no-]pretty-print          Determines if the output JSON is pretty printed
        --[no-]options-file [FILENAME]
                                      default: ~/.options/reach_engine
        --log-to FILENAME            Log file location.
                                      default: STDERR
        --log-level LEVEL            Logging level. Available Options: debug, info, warn, error, fatal
                                      default: debug
        -h, --help                   Show this message.

#### Options File

##### DEFAULT OPTIONS FILE PATH
    ~/.options/reach_engine

##### Example Options File Contents
    --reach-engine-server-address=10.42.1.70
    --api-key=12345678-abc1-4321-a11b-43ac890bd789
    --no-log-request-body
    --log-response-body
    --log-pretty-print-body
    --log-level=debug

#### Examples of Usage

##### Accessing help.
    ./reach_engine --help

##### Asset Search
    ./reach_engine asset_search

##### Asset Create
    ./reach_engine asset_create '{"file_to_ingest":"/assets/test.mov"}'

##### Asset Detail - Get the metadata for an Assets
    ./reach_engine asset_detail 12345678-abc1-4321-a11b-43ac890bd789
    ./reach_engine asset_detail '{ "asset_id":"12345678-abc1-4321-a11b-43ac890bd789" }'

##### Search Clips
    ./reach_engine clip_search

##### Clip Detail
    ./reach_engine clip_detail 12345678-abc1-4321-a11b-43ac890bd789
    ./reach_engine clip_detail '{ "clip_id":"12345678-abc1-4321-a11b-43ac890bd789" }'

##### Collection Search
    ./reach_engine collection_search
    
##### Collection Create
    ./reach_engine collection_create "Collection Name" '{"fieldName":"value"}'

##### Collection Detail
    ./reach_engine collection_detail 12345678-abc1-4321-a11b-43ac890bd789
    ./reach_engine collection_detail '{"collection_id":"12345678-abc1-4321-a11b-43ac890bd789"}'

##### Collection Member Add
    ./reach_engine collection_member_add Cf576b779-07cb-4f52-9e59-695ddbc2eb1d Clip 5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF
    ./reach_engine collection_member_add '{"collection_id":"12345678-abc1-4321-a11b-43ac890bd789", "member_class":"Clip", "member_id":"5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF"'

##### Collection Member Remove
    ./reach_engine collection_member_remove f576b779-07cb-4f52-9e59-695ddbc2eb1d Clip e8d497db-4f14-483a-ab1b-9db440e2f729
    ./reach_engine collection_member_remove '{"collection_id":"12345678-abc1-4321-a11b-43ac890bd789", "member_class":"Clip", "member_id":"5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF"'

##### Collection Member Search
    ./reach_engine collection_member_search 9f7d4d7f-921c-4ab1-88c8-ff95f15d741c
    ./reach_engine collection_member_search '{"collection_id":"12345678-abc1-4321-a11b-43ac890bd789"}'

##### Search - Provides interface to Elastic Search
    ./reach_engine search '{"types":"ImageAssetMaster|Project|Timeline", "rql":"name LIKE \\\\'ubiquity\\\\' SIZE 100 OFFSET 0 ORDER_BY dateUpdated DESC"}'

##### Timeline Clips
    ./reach_engine timeline_clips 5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF
    ./reach_engine timeline_clips '{"timeline_id":"5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF"}'

##### Timeline Detail
    ./reach_engine timeline_detail 5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF
    ./reach_engine timeline_detail '{"timeline_id":"5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF"}'

##### Timeline Search
    ./reach_engine timeline_search
    ./reach_engine timeline_search '{"search":"Mickey","media":"video"}'

##### Watch Folder Create
    ./reach_engine watch_folder_create '{"name":"API Watchfolder 23432","watch_folder":"/mnt/MediaSAN/zReachEngineDATA/media/temp/xplatform60/","max_concurrent":3,"delete_on_success":false,"workflow_key":"_ingestAssetToCollection","enabled":true,"file_data_def":"fileToIngest","subject":"[AssetCollection.70D1FD32-25FD-3716-C99A-52479EBA03CD.280]","contextData":{}}'

##### Watch Folder Create and Ingest Assets into Collection
    ./reach_engine create_watch_folder_and_ingest_assets_into_collection '{"name":"API Watchfolder 23432","watch_folder":"/mnt/MediaSAN/zReachEngineDATA/media/temp/xplatform60/","subject":"[AssetCollection.70D1FD32-25FD-3716-C99A-52479EBA03CD.280]"}'

##### Watch Folder Disable
    ./reach_engine watch_folder_disable 5194576f30045c8f72d99afa
    ./reach_engine watch_folder_disable '{"watch_folder_id":"5194576f30045c8f72d99afa"}'

##### Watch Folder Enable
    ./reach_engine watch_folder_enable 5194576f30045c8f72d99afa
    ./reach_engine watch_folder_enable '{"watch_folder_id":"5194576f30045c8f72d99afa"}'

##### Watch Folder Search
    ./reach_engine watch_folder_search

##### Workflow Detail
    ./reach_engine workflow_detail _archiveCollectionContents
    ./reach_engine workflow_detail '{"workflow_id":"_archiveCollectionContents"}'

##### Workflow Query
    ./reach_engine workflow_query
    ./reach_engine workflow_query '{"subject_class":"AssetCollection"}'

##### Workflow Resume
    ./reach_engine workflow_resume _archiveCollectionContents

##### Workflow Start
    ./reach_engine workflow_execution_start _archiveCollectionContents

##### Workflow Status
    ./reach_engine workflow_execution_status _archiveCollectionContents

##### Workflow Stop
    ./reach_engine workflow_execution_stop _archiveCollectionContents

Reach Engine API HTTP Server Executable [bin/reach_engine_api_http_server]
---------------------------------------

## Usage

    Usage: reach_engine_api_http_server [options]
            --binding BINDING            The address to bind the server to.
                                          default: 0.0.0.0
            --port PORT                  The port that the server should listen on.
                                          default: 4567
            --reach-engine-server-address ADDRESS
                                         The IP or hostname to use to contact the Reach Engine Server when one is not specified in incoming request arguments.
            --reach-engine-server-port PORT
                                         The port to use to contact the Reach Engine Server when one is not specified in incoming request arguments.
            --reach-engine-api-key API   The api-key to use when communicating with the Reach Engine Server when one is not specified in the incoming request arguments.
            --[no-]options-file [FILENAME]
                                          default: ~/.options/reach_engine_api_http_server
            --log-to FILENAME            Log file location.
                                          default: STDERR
            --log-level LEVEL            Logging level. Available Options: fatal, warn, info, error, debug
                                          default: info
        -h, --help                       Show this message.

#### Options File

##### DEFAULT OPTIONS FILE PATH
    ~/.options/reach_engine_api_http_server

##### Example Options File Contents
    --reach-engine-server-address=10.42.1.70
    --api-key=12345678-abc1-4321-a11b-43ac890bd789
    --log-level=debug

Reach Engine Watch Folder Generator [bin/reach_engine_watch_folder_generator]
-----------------------------------

  This utility generates files system folders and seeds them with files and then creates the watch folder in Reach
  Engine.

## Usage
    Usage: reach_engine_watch_folder_generator [options]
            --reach-engine-api-server-address SERVERADDRESS
                                         The address of the Reach Engine API server.
            --reach-engine-api-key APIKEY
                                         The API Key to use when communicating with the Reach Engine API server.
            --seed-file-path PATH        The path of the seed file.
            --watch-folder-root-directory-path PATH
                                         The path to the directory to create the watch folders in.
            --[no-]watch-folder-subject SUBJECT
                                         The subject to use when creating the watch folder.
                                         ex: "[AssetCollection.819FB58F-D007-09E7-F8B2-89FA1A2C4C27.200]"
            --number-of-watch-folders-to-create NUMBER
                                         The number of watch folders to create.
                                          default: 1
            --number-of-files-to-create NUMBER
                                         The number of seed files to copy into each newly created watch folder.
                                          default: 1
            --[no-]options-file [FILENAME]
                                          default: ~/.options/reach_engine_watch_folder_generator
            --log-to FILENAME            Log file location.
                                          default: STDERR
            --log-level LEVEL            Logging level. Available Options: error, fatal, info, warn, debug
                                          default: debug
        -h, --help                       Show this message.

#### Options File

##### DEFAULT OPTIONS FILE PATH
    ~/.options/reach_engine_watch_folder_generator

##### Example Options File Contents
    --reach-engine-api-server-address=10.42.1.70
    --reach_engine-api-key=12345678-abc1-4321-a11b-43ac890bd789
    --seed-file-path=/assets/test.mov
    --watch-folder-root-directory-path=/test/watch_folders
    --number-of-watch-folders-to-create=10
    --number-of-files-to-create=10
    --log-level=debug


Future Development
------------------

  Creation of a utility application that will creates a random number of watch folders, that will create a collection
  for each watch folder, that will copy a random number of files into each of those watch folder so that we can
  simulate the true maximum performance load in terms of what Reach Engine can handle.

  Creation of a command that will allow to create a watch folder by path and by specifying the Collection Name as a
  command line argument instead of requiring the user to specific the Collection ID and Elastic Search record id
  e.g. "[AssetCollection.70D1FD32-25FD-3716-C99A-52479EBA03CD.280]"




## Contributing

1. Fork it ( https://github.com/XPlatform-Consulting/levels_beyond/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Library Documentation
---------------------
  http://rubydoc.info/github/XPlatform-Consulting/levels_beyond

