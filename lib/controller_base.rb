require 'active_support'
require 'active_support/core_ext'
require 'active_support/inflector'
require 'erb'
require_relative './session'
require_relative './flash'

class ControllerBase
  attr_reader :req, :res, :params
  @@protect_from_forgery = false

  # Setup the controller
  def initialize(req, res, route_params = {})
    @res = res
    @req = req
    @params = req.params.merge(route_params)
  end

  def already_built_response?
    @already_built_response
  end

  # Set the response status code and header
  def redirect_to(url)
    if already_built_response?
      raise 'multiple render/redirect error'
    end
    res.header['location'] = url
    res.status = 302
    @already_built_response = true
    session.store_session(res)
    flash.store_session(res)
  end

  # Populate the response with content.
  # Set the response's content type to the given type.
  # Raise an error if the developer tries to double render.
  def render_content(content, content_type)
    if already_built_response?
      raise 'multiple render/redirect error'
    end
    res['Content-Type'] = content_type
    res.write(content)
    @already_built_response = true
    session.store_session(res)
    flash.store_session(res)
  end

  # use ERB and binding to evaluate templates
  # pass the rendered html to render_content
  def render(template_name)
    path = "views/#{self.class.to_s.underscore}/#{template_name}.html.erb"
    template = ERB.new(File.read(path))
    render_content template.result(binding), 'text/html'
  end

  def flash
    @flash ||= Flash.new(req)
  end

  # method exposing a `Session` object
  def session
    @session ||= Session.new(req)
  end

  # use this with the router to call action_name (:index, :show, :create...)
  def invoke_action(name)
    if req.request_method.to_s.downcase != "get" && self.class.protect_from_forgery?
      check_authenticity_token
    else
      form_authenticity_token
    end

    self.send(name)
    render(name.to_s) unless @already_built_response
  end

  def form_authenticity_token
    @token ||= SecureRandom::urlsafe_base64(16)
    res.set_cookie(
      'authenticity_token',
      { path: '/', value: @token }
    )
    @token
  end

  def check_authenticity_token
    auth_token = req.cookies['authenticity_token']
    unless auth_token && auth_token == params['authenticity_token']
      raise 'Invalid authenticity token'
    end
  end

  def self.protect_from_forgery
    @@protect_from_forgery = true
  end

  def self.protect_from_forgery?
    @@protect_from_forgery
  end
end
