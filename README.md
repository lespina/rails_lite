# Ruby on Trails README

Ruby On Trails is a lightweight implementation of the core functionality of the Rails and Active Record Model-View-Controller framework.  

For proof of concept, please check out [HungryHippos](http://52.70.147.99/feed), a simple, silly, full-stack web application built entirely using Ruby on Trails and SQLite3!

HungryHippos:
- [live](http://52.70.147.99/feed)
- [github](https://github.com/lespina/hungry-hippos)

## Table of Contents

- [Active Record Lite](#active-record-lite)
  - [SQLObject](#sqlobject)
    - [Searchable Module](#searchable-module)
    - [Associatable Module](#associatable-module)
  - [DBConnection](#dbconnection)
- [ControllerBase](#controller-base)
  - [Render & Redirect](#render-&-redirect)
  - [Flash](#flash)
  - [Session](#session)
  - [CSRF Protection](#csrf-protection)
- [Routing](#routing)
  - [Route](#route)
  - [Router](#router)
- [Middlewares](#middlewares)
  - [Static Assets](#static-assets)
  - [Show Exceptions](#show-exceptions)
- [Starting the Server](#server)


### Active Record Lite

The first major component underlying Ruby on Trails is an implementation of the Object Relational Mapper (ORM), Active Record.  For clarity, we will refer to the Ruby on Trails implementation as 'Active Record Lite'.  All relevant code may be found in [/lib/active_record_lite/](https://github.com/lespina/ruby_on_trails/tree/master/lib/active_record_lite).

#### SQLObject

SQLObject is the base model class that utilizes meta-programming to dynamically create properly mapped models from relational database tables at runtime.  In order to map each model to its corresponding relation in the database, SQLObject implements two key methods:

```ruby
class SQLObject
  def self.columns
    @columns ||=
      DBConnection.execute2(<<-SQL)
        SELECT
          *
        FROM
          #{table_name}
      SQL
      .first.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |column|
      col_attr_reader column
      col_attr_writer column
    end
    nil
  end
  ...
end
```
At the top of every model object definition, self.finalize! is called.  

```ruby
class ExampleModel < SQLObject
  self.finalize!
  ...
end
```

This method queries the database through the DBConnection class (see [below](#dbconnection) for more details) and grabs each column, defining getters and setters (attribute readers/writers) for each one through use of ruby's Object#define_method method.

```ruby
class SQLObject
  ...
  def self.col_attr_reader(*cols)
    cols.each do |col|
      define_method(col) do
        attributes[col]
      end
    end
  end

  def self.col_attr_writer(*cols)
    cols.each do |col|
      define_method("#{col}=".to_sym) do |value|
        attributes[col] = value
      end
    end
  end
  ...
```

In addition, SQLObject provides an API to query the database for the given relation with ::all, ::find(id), #insert, and #save.

Finally, SQLObject extends two different modules for search and associations:

```ruby
class SQLObject
  ...
  extend Searchable
  extend Associatable
  ...
end
```

###### Searchable Module
SQLObject integrates a Searchable module, wherein conditional querying functionality is provided through the #where method.

```ruby
module Searchable

  def where(params)
    conditionals = params.map { |column, _| "#{column} = ?" }

    results = DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{conditionals.join(" AND ")}
    SQL

    self.parse_all(results)
  end
  ...
end
```

This allows the user to query the database with equality-check conditionals without using pure SQL, like so:

```ruby
User.where(name: 'Simon')
```

###### Associatable Module
SQLObject utilizes an Associatable module, wherein has_many, belongs_to, and has_one_through meta-programming methods are defined that create new methods for associated relations when invoked in model class definitions.

```ruby
module Associatable
  def belongs_to(name, options = {})
    options = BelongsToOptions.new(name, options)
    assoc_options[name] = options

    define_method(name) do
      foreign_key_id = self.send(options.foreign_key)
      result = options.model_class.where(id: foreign_key_id)
      result.first
    end
  end

  def has_many(name, options = {})
    options = HasManyOptions.new(name, self.to_s, options)

    define_method(name) do
      options.model_class.where(options.foreign_key => self.id)
    end
  end

  def assoc_options
    @assoc_options ||= {}
  end

  def has_one_through(name, through_name, source_name)
    define_method(name) do
      through_options = self.class.assoc_options[through_name]
      source_options =
        through_options.model_class.assoc_options[source_name]

      foreign_key_id = self.send(through_options.foreign_key)
      result = through_options.model_class.where(id: foreign_key_id)
      sub_result = result.first

      foreign_key_id = sub_result.send(source_options.foreign_key)
      result = source_options.model_class.where(id: foreign_key_id)
      result.first
    end
  end
end
```
<sup>BelongsToOptions & HasManyOptions inherit from AssocOptions, which provides attr_accessors for foreign_key, class_name, and primary_key, as well as helper methods to obtain the table_name and class_name (the gem, 'active_support/inflector', is used for this).  For more information, please check the [source file](https://github.com/lespina/ruby_on_trails/blob/master/lib/active_record_lite/associatable.rb).
</sup>

Hence, the developer may easily define associations on their model classes like so:

```ruby
class User < SQLObject
  belongs_to :cat,
  has_many :things,
  has_one :cat_toy,
    through: :cat,
    source: :cat_toy
end
```

##### DBConnection

<sup>N.B. The given db_connection.rb file will throw an error when run as is -- it expects an arbitrary 'example.sql' SQLite3 database setup file in the root directory to connect into the SQLObject model.   Users who are so inclined may write their own database setup file to see this function in action, but for a working example, please see the [HungryHippos repository](https://github.com/lespina/hungry_hippos).</sup>

SQLObject depends upon DBConnection to query the database.  Under the hood, DBConnection implements something akin to a Singleton pattern, using DBConnection::instance to ensure only a single connection to the concerned database is opened at any one time.

```ruby
class DBConnection

  def self.instance
    reset if @db.nil?

    @db
  end

  def self.reset
    commands = [
      "rm '#{EXAMPLE_DB_FILE}'",
      "cat '#{EXAMPLE_SQL_FILE}' | sqlite3 '#{EXAMPLE_DB_FILE}'"
    ]

    commands.each { |command| `#{command}` }
    DBConnection.open(EXAMPLE_DB_FILE)
  end

  def self.open(db_file_name)
    @db = SQLite3::Database.new(db_file_name)
    @db.results_as_hash = true
    @db.type_translation = true

    @db
  end
  ...
end
```
<sup>N.B. 'EXAMPLE_DB_FILE' and 'EXAMPLE_SQL_FILE' correspond to the full path to some 'example.db' database and 'example.sql' setup file</sup>

SQLObject utilizes DBConnection::execute2 and DBConnection::execute to query the database using the single connection initialized on the DBConnection class.

These methods defer to the corresponding methods in the SQLite::Database API (recall 'instance' refers to an instance of a SQLite3::Database object).

```ruby
class DBConnection
  ...
  def self.execute(*args)
    print_query(*args)
    instance.execute(*args)
  end

  def self.execute2(*args)
    print_query(*args)
    instance.execute2(*args)
  end
  ...
end
```

#### ControllerBase

The second major component underlying Ruby on Trails is ControllerBase, the parent class of all eventual controller instances corresponding to relations in the SQLite3 database.  For more information, please check out the [source file](https://github.com/lespina/ruby_on_trails/blob/master/lib/controller_base.rb).

ControllerBase initializes with a Rack::Request, Rack::Response, and route parameters.  These route params are merged with the request params and stored in a general params hash that works like the native rails params hash.

```ruby
class ControllerBase

  attr_reader :req, :res, :params

  def initialize(req, res, route_params = {})
    @res = res
    @req = req
    @params = req.params.merge(route_params)
  end
  ...
end
```

#### Render & Redirect

ControllerBase implements several methods to handle serving content when #render and #redirect are called in child instances.

```ruby
class ControllerBase
  ...
  def already_built_response?
    @already_built_response
  end

  # Sets the proper redirect status code and header
  # Raises an error in the case of a double render.
  def redirect_to(url)
    if already_built_response?
      raise 'multiple render/redirect error'
    end
    res.header['location'] = url
    res.status = 302
    @already_built_response = true
    ...
  end

  # Populates the response with content.
  # Sets the response's content type.
  # Raises an error in the case of a double render.
  def render_content(content, content_type)
    if already_built_response?
      raise 'multiple render/redirect error'
    end
    res['Content-Type'] = content_type
    res.write(content)
    @already_built_response = true
    ...
  end

  # uses ERB and binding to evaluate templates
  # passes the rendered html to render_content
  def render(template_name)
    path = "views/#{self.class.to_s.underscore}/#{template_name}.html.erb"
    template = ERB.new(File.read(path))
    render_content template.result(binding), 'text/html'
  end
...
end
```

Just like in the actual implementation of Rails, we favor convention over configuration and assume a standardized path to the views to be rendered:

"views/#{snake_cased_class_name}/#{template_name}.htmlerb"

So long as this convention is followed, calling render on a string or symbol template name will serve a view with the corresponding name.

As you may have noticed, we also perform a check to make sure the developer has not attempted to render or redirect twice within the lifetime of a controller instance.

#### Flash & Session

In addition to allowing the user to render and redirect, ControllerBase provides the session, flash, and flash.now hashes.  First, we'll review Session.

```ruby
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
```

First, we find the corresponding request cookie (in this case, named arbitrarily as '\_rails\_lite\_app', but this can be changed by the developer if they so choose).  Then we deserialize the cookie and store it as a hash that may be keyed into.  

When we store the session, we simply use the Rack::Request#set_cookie method.  Intuitively, this hash persists for the lifetime of the controller instance.

Next, let's look at the Flash.

```ruby
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
```

The implementation of these objects is fairly similar.  The main difference is that we have to keep track of both a flash and flash.now hash, which have differing persistence of content.

Flash.now is taken care of by utilizing a separate instance variable when initializing the Flash object for \@now and \@flash, then only allowing the user to add new key, value pairs into the \@flash hash.  This way, the only items accessible in flash.now will be the ones set when we initialize the  Flash object.

##### Storing the session & flash

The above versions of redirect and render_content ommitted these lines for clarity, but they actually store the session and flash at the end of their method definitions like so:

```ruby
class ControllerBase
  def redirect_to(url)
    ...
    session.store_session(res)
    flash.store_session(res)
  end

  def render_content(content, content_type)
    ...
    session.store_session(res)
    flash.store_session(res)
  end
end
```

#### CSRF Protection

One more thing Ruby on Trails provides is optional CSRF protection.  The user can toggle this option on a specific controller by calling ControllerBase::protect_from_forgery, or (more commonly) calling this on a sub-parent class, usually named ApplicationController that all other controllers inherit from.

```ruby
class ControllerBase
  ...
  @@protect_from_forgery = false

  def self.protect_from_forgery
    @@protect_from_forgery = true
  end

  def self.protect_from_forgery?
    @@protect_from_forgery
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

  def invoke_action(name)
    if req.request_method.to_s.downcase != "get" && self.class.protect_from_forgery?
      check_authenticity_token
    else
      form_authenticity_token
    end

    self.send(name)
    render(name.to_s) unless @already_built_response
  end
  ...
```
As shown above, when ControllerBase::protect_form_forgery is
called, every non-get request must pass an authenticity token
check before invoking the corresponding action.  The method,
ControllerBase#check_authenticity_token, compares the request
token to the one stored in the params hash, and raises an
error if the two do not match.

```erb
<form action="/example_route" method="POST">
...
  <input type="hidden" name="authenticity_token" value="<%= form_authenticity_token %>">
...
</form>
```

Thus, in the HTML of the any form in a Ruby on Trails app, it is necessary to send up a hidden input containing the matching form_authenticity_token generated by Ruby on Trails and saved as a cookie client-side or the request will never hit the matching controller method.


#### Routing

The third major component underlying Ruby on Trails is the Routing functionality.  For more information, please chout out the [source file](https://github.com/lespina/ruby_on_trails/blob/master/lib/router.rb).

Ruby on Trails differs slightly from true Ruby on Rails, where new routes must be defined within the block of a Router#draw method using regex expressions, like so:

```ruby
  router = Router.new
  router.draw do
    get Regexp.new("^/things$"), ThingsController, :index
    get Regexp.new("^/things/(?<id>\\d+)$"), ThingsController, :show
    get Regexp.new("^/things/new$"), ThingsController, :new
    post Regexp.new("^/things$"), ThingsController, :create
  end
```

After evaluating this block of code and [starting the server](#server), the router will initialize the appropriate controller and call the corresponding action for each defined route.

##### Router
Ruby on Trails is able to define routes via the Router#draw method:

```ruby
#router.rb
class Router
  ...
  # adds a route to the internal list of routes
  def add_route(pattern, method, controller_class, action_name)
    @routes << Route.new(pattern, method, controller_class, action_name)
  end
  ...
  # syntactic sugar to evaluate the proc in the
  # context of the instance
  def draw(&proc)
    self.instance_eval(&proc)
  end
  ...
  # dynamically defines methods for each HTTP verb at runtime
  # that, when called, add a route with the corresponding verb
  [:get, :post, :put, :patch, :delete].each do |http_method|
    define_method(http_method) do |pattern, controller_class, action_name|
      add_route(pattern, http_method, controller_class, action_name)
    end
  end
  ...
end
```

Router#draw evaluates the given proc in the context of the instance it is invoked.  Inside, calls to get, post, put, and delete invoke methods that are defined at class definition time through the use of ruby's define_method.

These 'HTTP verb' methods initialize and store new routes according to the passed in variables, which include a regex pattern, controller type, and symbolized action name.  

```ruby
class Route
  attr_reader :pattern, :http_method, :controller_class, :action_name

  def initialize(pattern, http_method, controller_class, action_name)
    @pattern = pattern
    @http_method = http_method
    @controller_class = controller_class
    @action_name = action_name
  end
  ...
end
```

When the end user submits a new request from their browser, it is routed to a new instance of the some Controller via calling the Router#run, and subsequently the Route#run, methods.

```ruby
class Router
  ...
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

class Route
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
```

#### Middlewares
The fourth component underlying Ruby on Trails is a couple of middlewares:
'ShowExceptions' and 'StaticAssets'.

A processed app is built with component middlewares like so before being passed to the server:

```ruby
app = Proc.new do |env|
  req = Rack::Request.new(env)
  res = Rack::Response.new
  router.run(req, res)
  res.finish
end

app = Rack::Builder.new do
  use FirstMiddleware
  use SecondMiddleware
  ...
  run app
end.to_app
```


Each middleware must implement an initialize(app) method that stores a reference to the app, as well as a #call method that will execute the desired middleware functionality on the app when passed to Rack::Builder.

##### Show Exceptions
The ShowExceptions middleware provides functionality to display custom exceptions views and messages.

```ruby
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
```
In this implementation, we simply make all thrown exceptions result in 500 internal server errors that render a barebones template, but by chaning the render_exception(e) method, developers can curate their own exception handling scheme.

##### Static Assets
Then Static middleware allows end users and the developer to access files stored in the [/public](https://github.com/lespina/ruby_on_trails/tree/master/public) directory by sending a 'GET' http request to the hosted domain at "#{domain}/public/#{filename}".

```ruby
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
```

#### Starting The Server
The fifth and final piece of the Ruby on Trails framework is functionality to start the server.  Here, we defer that work to the Rack::Server API.  The simplest example is given below:

```ruby
app = Proc.new do |env|
  req = Rack::Request.new(env)
  res = Rack::Response.new
  router.run(req, res)
  res.finish
end

Rack::Server.start(
  app: app,
  Port: 3000
)
```

For example, the developer may write this code in its own file, perhaps named "start_server.rb" and start the server by simply running 'ruby start_server.rb'.

##### Future Directions:

* Add SQLObject#joins and SQLObject#validates methods
* Add ControllerBase#link_to and ControllerBase#button_to methods
* Add strong params functionality (i.e. #require, #permit)
* Add URL route helpers (ex. users_url for '/users')
