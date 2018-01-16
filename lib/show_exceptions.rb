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
    template = File.read('lib/templates/rescue.html.erb')
    content = ERB.new(template).result(binding)
    ['500', {'Content-type' => 'text/html'}, content]
  end

end
