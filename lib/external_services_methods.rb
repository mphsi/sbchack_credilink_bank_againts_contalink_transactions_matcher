module ExternalServicesMethods
  def bank_request_headers
    {
      'x-api-key' => ENV['API_KEY'],
      'X-Client' => ENV['CLIENT'],
      'X-User' => ENV['USER'],
      'X-Password' => ENV['PASSWORD'],
    }
  end

  def call_bank_web_service(endpoint, headers, query_params = nil)
    uri           = URI.parse(endpoint)
    http          = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl  = uri.scheme == 'https'
    uri.query     = query_params.nil? ? nil : URI.encode_www_form(query_params)
    request       = Net::HTTP::Get.new(uri.request_uri, headers)

    http.request(request)
  end

  def response_body(response)
    JSON.parse(response.body)
  end
end