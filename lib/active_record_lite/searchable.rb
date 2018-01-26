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

end

class SQLObject
  extend Searchable
end
