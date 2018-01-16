require 'erb'

class ShowExceptions
  attr_reader :app

  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      app.call(env)
    rescue
      render_exception(env)
    end
  end

  private

  def render_exception(e)
    # exceptions_file = File.read('templates/rescue.html.erb')
    # res = Rack::Response.new
    # res.status = 500
    # res['Content-Type'] = 'text/html'
    # res.write('RuntimeError')
    ['500', {'Content-type' => 'text/html'}, 'RuntimeError']
  end

end
