require_relative 'db_connection'
require_relative 'sql_object'

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

  def joins(table_to_join)
    other_table = table_to_join.to_s
    results = DBConnection.execute(<<-SQL, other_table)
      SELECT
        *
      FROM
        #{self.table_name}
      JOIN
        ? ON
          #{self.table_name}.id = #{other_table}.#{other_table.singularize}_id
    SQL

    self.parse_all(results)
  end
end

class SQLObject
  extend Searchable
end
