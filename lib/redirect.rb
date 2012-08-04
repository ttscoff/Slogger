class RedirectFollower
  class TooManyRedirects < StandardError; end

  attr_accessor :url, :body, :redirect_limit, :response

  def initialize(url, limit=5)
    @url, @redirect_limit = url, limit
  end

  def resolve
    raise TooManyRedirects if redirect_limit < 0

    self.response = Net::HTTP.get_response(URI.parse(url))
    if response.kind_of?(Net::HTTPRedirection)
      self.url = redirect_url
      self.redirect_limit -= 1
      resolve
    end

    self.body = response.body
    self
  end

  def redirect_url
    if response['location'].nil?
      response.body.match(/<a href=\"([^>]+)\">/i)[1]
    else
      response['location']
    end
  end
end
