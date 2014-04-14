require 'levels_beyond/version'

if RUBY_VERSION < '1.9'
  require 'rubygems'
  require 'net/https'
  begin
    require 'json'
  rescue LoadError
    begin
      require 'json/pure'
    rescue LoadError
      abort("JSON GEM Missing.\nTo install a native (compiled/faster/more complicated to install) version run: 'gem install json'\n\tOR\nTo install a ruby only (non-compiled/slower/less complicated to install) version run: 'gem install json_pure'")
    end
  end
else
  require 'net/http'
  require 'json'
end
require 'logger'

module LevelsBeyond

end
