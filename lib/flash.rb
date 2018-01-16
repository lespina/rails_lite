require 'json'
require 'byebug'
require 'active_support'

class Flash
  def initialize(req)
    cookie = req.cookies['_rails_lite_app_flash']
    @now = (cookie) ? JSON.parse(cookie) : {}
    @flash = {}
  end

  def store_flash(res)
    res.set_cookie(
      '_rails_lite_app_flash',
      { path: '/', value: JSON.generate(@flash) }
    )
  end

  def now
    @now
  end

  def [](key)
    @now[key.to_s] || @flash[key.to_s]
  end

  def []=(key, value)
    @flash[key.to_s] = value
  end
end
