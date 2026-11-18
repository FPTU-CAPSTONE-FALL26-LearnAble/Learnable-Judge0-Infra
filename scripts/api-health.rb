require 'net/http'

begin
  config = File.readlines('/judge0.conf').filter_map do |line|
    line.strip.split('=', 2) if line.start_with?('AUTHN_HEADER=', 'AUTHN_TOKEN=')
  end.to_h
  request = Net::HTTP::Get.new('/languages')
  request[config.fetch('AUTHN_HEADER')] = config.fetch('AUTHN_TOKEN')
  http = Net::HTTP.new('127.0.0.1', 2358, nil)
  http.open_timeout = 2
  http.read_timeout = 2
  exit(http.request(request).code == '200' ? 0 : 1)
rescue StandardError
  exit 1
end
