require 'json'
require 'byebug'
require 'active_support'

class Flash
  def initialize(req)
    @@to_delete ||= [[], []]
    @req = req
    cookie = req.cookies['_rails_lite_app_flash']
    @flash = (cookie) ? JSON.parse(cookie) : {}
  end

  def store_flash(res)
    @flash.except!(*@@to_delete.first)
    @@to_delete.rotate!

    res.set_cookie '_rails_lite_app_flash', { path: '/', value: JSON.generate(@flash) }

    @@to_delete[1] = @flash.keys
  end

  def [](key)
    @flash[key.to_s]
  end

  def []=(key, value)
    @flash[key.to_s] = value
  end
end
