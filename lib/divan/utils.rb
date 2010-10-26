module Divan
  module Utils
    def self.uuid
      values = [ rand(0x0010000), rand(0x0010000), rand(0x0010000), rand(0x0010000),
                 rand(0x0010000), rand(0x1000000), rand(0x1000000) ]
      "%04x%04x%04x%04x%04x%06x%06x" % values
    end

    def self.parse_time(string)
      parsed_time     = Date._parse string
      Time.gm *[:year, :mon, :mday, :hour, :min, :sec].collect{ |k| parsed_time[k] }
    end

    def self.formatted_path(path = nil, opts = {})
      if opts.empty?
        CGI.escape path.to_s
      else
        formatted_opts = opts.map{|k,v| "#{CGI.escape k.to_s}=#{URI.encode v.to_s}"}.join('&')
        "#{path.to_s}?#{formatted_opts}"
      end
    end
  end
end
