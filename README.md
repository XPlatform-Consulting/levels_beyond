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

##### DEFAULT OPTIONS FILE PATH
  ~/.options/reach_engine

##### Example Options File Contents:
    --reach-engine-server-address=10.42.1.70
    --api-key=12345678-abc1-4321-a11b-43ac890bd789
    --no-log-request-body
    --log-response-body
    --log-pretty-print-body
    --log-level=debug

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
                                      default: /Users/xplatformconsulting/development/levels_beyond/bin/reach_engine_options
        --log-to FILENAME            Log file location.
                                      default: STDERR
        --log-level LEVEL            Logging level. Available Options: debug, info, warn, error, fatal
                                      default: debug
        -h, --help                   Show this message.

#### Examples of Usage:

##### Accessing help.
    ./reach_engine --help

##### Search Assets
    ./reach_engine asset_search

##### Asset Detail
    ./reach_engine asset_detail 12345678-abc1-4321-a11b-43ac890bd789

##### Search Clips
    ./reach_engine clip_search

##### Clip Detail
    ./reach_engine clip_detail 12345678-abc1-4321-a11b-43ac890bd789

##### Collection Create
    ./reach_engine collection_create "Collection Name" '{"fieldName":"value"}'

##### Collection Detail
    ./reach_engine collection_detail 12345678-abc1-4321-a11b-43ac890bd789

##### Collection Member Add
    ./reach_engine collection_member_add Clip 5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF

##### Collection Member Remove
    ./reach_engine collection_member_remove f576b779-07cb-4f52-9e59-695ddbc2eb1d Clip e8d497db-4f14-483a-ab1b-9db440e2f729

##### Collection Member Search
    ./reach_engine collection_member_search 9f7d4d7f-921c-4ab1-88c8-ff95f15d741c

##### Search
    ./reach_engine search '{"types":"ImageAssetMaster|Project|Timeline", "rql":"name LIKE \\\\'ubiquity\\\\' SIZE 100 OFFSET 0 ORDER_BY dateUpdated DESC"}'

##### Timeline Clips
    ./reach_engine timeline_clips 5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF

##### Timeline Detail
    ./reach_engine timeline_detail 5564AEEE-8433-D9C7-2BA7-DBEDD866B3CF

##### Timeline Search
    ./reach_engine timeline_search '{"search":"Mickey","media":"video"}'

##### Watch Folder Create
    ./reach_engine watch_folder_create '{"name":"API Watchfolder 23432","watch_folder":"/mnt/XPlatformSAN/zReachEngineDATA/media/temp/xplatform60/","max_concurrent":3,"delete_on_success":false,"workflow_key":"ingestAssetToCollection","file_data_def":"fileToIngest","subject": "[AssetCollection.70D1FD32-25FD-3716-C99A-52479EBA03CD.280]","contextData":{}}'

##### Watch Folder Disable
    ./reach_engine watch_folder_disable 5194576f30045c8f72d99afa

##### Watch Folder Enable
    ./reach_engine watch_folder_enable 5194576f30045c8f72d99afa

##### Watch Folder Search
    ./reach_engine watch_folder_search

##### Watch Folder Detail
    ./reach_engine watch_folder_detail _archiveCollectionContents

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


## Contributing

1. Fork it ( http://github.com/<my-github-username>/levels_beyond/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
