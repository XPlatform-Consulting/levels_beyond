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
                                      default: /Users/jw/Dropbox/projects/DC/work/levels_beyond/bin/reach_engine_options
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



## Contributing

1. Fork it ( http://github.com/<my-github-username>/levels_beyond/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
