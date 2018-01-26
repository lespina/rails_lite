require 'json'

class Session
  def initialize(req)
    cookie = req.cookies['_rails_lite_app']
    if cookie
      @cookie = JSON.parse(cookie)
    else
      @cookie = {}
    end
  end

  def [](key)
    @cookie[key]
  end

  def []=(key, val)
    @cookie[key] = val
  end

  def store_session(res)
    res.set_cookie(
      '_rails_lite_app',
      { path: '/', value: JSON.generate(@cookie) }
    )
  end
end
