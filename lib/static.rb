require 'byebug'

class Static
  MIME_TYPES = {
    '.txt' => 'text/plain',
    '.jpg' => 'image/jpeg',
    '.zip' => 'application/zip'
  }

  PUBLIC_REGEX = /\/public\/(.+)/

  attr_reader :app

  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)

    path = req.path

    if path =~ PUBLIC_REGEX
      read_asset(req)
    else
      app.call(env)
    end
  end

  def read_asset(req)

    res = Rack::Response.new

    match_data = PUBLIC_REGEX.match(req.path)
    filename = "public/#{match_data[1]}"

    unless File.file?(filename)
      res.status = 404
      return res.finish
    end

    content = File.read(filename)
    content_type = File.extname(filename)
    res['Content-type'] = content_type
    res.write(content)
    res.finish
  end
end
