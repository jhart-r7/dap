require 'open-uri'

module Dap
module Utils

  def self.update
    maxmind_uri = 'http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz'
    maxmind_gz = File.join(Dap::Filter::GeoIPLibrary::GEOIP_DATA_DIR, File.basename(maxmind_uri))
    maxmind_dat = maxmind_gz.gsub(/\.gz$/, '')
    fetch(maxmind_uri, maxmind_gz)
    Zlib::GzipReader.open(maxmind_gz) do |gz|
      File.open(maxmind_dat, "w") do |dat|
        IO.copy_stream(gz, dat)
      end
    end

    iana_uri = 'https://data.iana.org/TLD/tlds-alpha-by-domain.txt'
    iana_txt = File.join(Dap::DATA_DIR, File.basename(iana_uri))
    fetch(iana_uri, iana_txt)
  end

  private

  def self.fetch(from, to)
    IO.copy_stream(open(from), to)
  end

end
end
