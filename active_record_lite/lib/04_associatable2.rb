require_relative '03_associatable'

# Phase IV
module Associatable
  # Remember to go back to 04_associatable to write ::assoc_options

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
