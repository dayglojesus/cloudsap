#https://stackoverflow.com/questions/22219499/disable-rackcommonlogger-without-monkey-patching
module Rack
  class CommonLogger
    def log(env, status, header, began_at)
      # We don't launch using rackup and we don't want to log any http requests,
      # so just quell any attempts at Rack logging things.
    end
  end
end