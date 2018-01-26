require_relative 'db_connection'
require 'active_support/inflector'

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

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= (self.to_s.tableize)
  end

  def self.all
    results =
      DBConnection.execute(<<-SQL)
        SELECT
          *
        FROM
          #{table_name}
      SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map do |sql_object_hash|
      self.new(sql_object_hash)
    end
  end

  def self.find(id)
    result =
      DBConnection.execute(<<-SQL, id)
        SELECT
          *
        FROM
          #{table_name}
        WHERE
          id = ?
      SQL
    result.empty? ? nil : self.new(result.first)
  end

  def initialize(params = {})
    params.each do |col_name, value|
      raise "unknown attribute '#{col_name}'" unless self.class.columns.include?(col_name.to_sym)

      col_setter = "#{col_name}=".to_sym
      self.send(col_setter, value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |col_name| value = self.send(col_name) }
  end

  def insert
    attributes[:id] = DBConnection.last_insert_row_id

    col_names = self.class.columns
    question_marks = ["?"] * col_names.size

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names.join(", ")})
      VALUES
        (#{question_marks.join(", ")})
    SQL
  end

  def update
    col_setters = self.class.columns.map { |col| "#{col} = ?" }[1..-1]

    DBConnection.execute(<<-SQL, *(attribute_values.rotate))
      UPDATE
        #{self.class.table_name}
      SET
        #{col_setters.join(", ")}
      WHERE
        id = ?
    SQL
  end

  def save
    self.class.find(self.id) ? update : insert
  end
end
