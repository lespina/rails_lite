# Ruby on Trails README

Ruby On Trails is a lightweight implementation of the core functionality of the Rails and Active Record Model-View-Controller framework.  For proof of concept, please check out [HungryHippos](https://github.com/lespina/hungry_hippos), a simple, silly, full-stack web application built entirely using Ruby on Trails and SQLite3!

### Active Record Lite

Underlying Ruby on Trails is an implementation of the Object Relational Mapper (ORM), Active Record.  For clarity, we will refer to the Ruby on Trails implementation as 'Active Record Lite'.  All relevant code may be found in '/lib/active_record_lite/'.

#### SQLObject

SQLObject is the base model class that utilizes meta-programming to dynamically create properly mapped models from relational database tables at runtime.  In order to map each model to its corresponding database, SQLObject implements two key methods:

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

This method queries the database through the DBConnection class (see below for more details) and grabs each column, defining getters and setters (attribute readers/writers) for each one through use of ruby's Object#define_method method.

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
