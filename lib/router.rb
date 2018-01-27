class Route
  attr_reader :pattern, :http_method, :controller_class, :action_name

  def initialize(pattern, http_method, controller_class, action_name)
    @pattern = pattern
    @http_method = http_method
    @controller_class = controller_class
    @action_name = action_name
  end

  # checks if both the pattern matches the request path and the
  # internal http method matches request http method
  def matches?(req)
    @pattern.match?(req.path) && @http_method.to_s.downcase == req.request_method.downcase
  end

  # instantiates the controller and invokes the controller action
  def run(req, res)
    match_data = @pattern.match(req.path)
    route_params = (match_data) ?
      match_data.names.zip(match_data.captures).to_h
      : {}

    controller_instance = @controller_class.new(req, res, route_params)

    controller_instance.invoke_action(@action_name)
  end
end

class Router
  attr_reader :routes

  def initialize
    @routes = []
  end

  # adds a route to the internal list of routes
  def add_route(pattern, method, controller_class, action_name)
    @routes << Route.new(pattern, method, controller_class, action_name)
  end

  # syntactic sugar to evaluate the proc in the
  # context of the instance
  def draw(&proc)
    self.instance_eval(&proc)
  end

  # dynamically defines methods for each HTTP verb at runtime
  # that, when called, add a route with the corresponding verb
  [:get, :post, :put, :delete].each do |http_method|
    define_method(http_method) do |pattern, controller_class, action_name|
      add_route(pattern, http_method, controller_class, action_name)
    end
  end

  def match(req)
    @routes.each do |route|
      return route if route.matches?(req)
    end
    return nil
  end

  # call run on a matched route or throw a 404 not found error
  def run(req, res)
    matched_route = match(req)
    if matched_route
      matched_route.run(req, res)
    else
      res.status = 404
      res.write("No route matches #{req.fullpath}")
    end
  end
end
