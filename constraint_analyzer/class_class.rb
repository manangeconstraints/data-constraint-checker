class Class_class
	attr_accessor :filename, :class_name, :upper_class_name, :ast, :is_activerecord, :is_deleted, :indices
	def initialize(filename)
		@filename = filename
		@is_activerecord = false
		@class_name = nil
		@upper_class_name = nil
		@ast = nil
		@constraints = {}
		@columns = {}
		@is_deleted = false
		@indices = {}
	end
	def addConstraints(constraints)
		constraints.each do |constraint|
			# puts"constraint #{constraint.class}"
			key = "#{constraint.column}-#{constraint.class.name}-#{constraint.type}"
			@constraints[key] = constraint
			constraint.table = self.class_name
		end
		puts"@constraints.size #{@constraints.length}"
	end
	def getConstraints
		return @constraints
	end
	def getColumns
		return @columns
	end
	def addColumn(column)
		@columns[column.column_name] = column
	end
	def addIndex(index)
		@indices[index.name] = index
	end
	def create_con_from_column_type
		@columns.each do |k, v|
			type = 'db'
			column_type = v.column_type 
			if column_type == "string" 
				max_value = 255
			end
			if column_type == "text"
				max_value = 66536
			end
			column_name = v.column_name
			puts "max_value from type: #{max_value} #{column_name} #{column_type} #{@class_name}"
			if max_value
				constraint = Length_constraint.new(@class_name, column_name, type)
				constraint.max_value = max_value
				key = "#{constraint.column}-#{constraint.class.name}-#{constraint.type}"
				exist_con = @constraints[key]
				if exist_con and (not exist_con.max_value || exist_con.max_value == "nil")
					exist_con.max_value = max_value
				end
				if not exist_con
					@constraints[key] = constraint
				end
			end
			if ["float", "integer", "decimal"].include?column_type
				constraint = Numericality_constraint.new(@class_name, column_name, type)
				if column_type == "integer"
					constraint.only_integer = true
				end
				key = "#{constraint.column}-#{constraint.class.name}-#{constraint.type}"
				@constraints[key] = constraint
			end
		end
	end
	def create_con_from_index
		@indices.each do |k, v|
			if v.unique
				type = "db"
				v.columns.each do |column|
					constraint = Uniqueness_constraint.new(@class_name, column, type)
					key = "#{constraint.column}-#{constraint.class.name}-#{constraint.type}"
					@constraints[key] = constraint
				end	
			end
		end
	end
	def create_con_from_format
		@constraints.each do |k, v|
			if v.is_a?Format_constraint and format = v.format
				constraint = derive_length_constraint_from_format(v)
				self.addConstraints([constraint])
			end
		end
	end
end
class Column
	# belongs to model class which is active record
	attr_accessor :column_type,  :column_name, :file_class, :prev_column, :is_deleted, :default_value, :table_class
	def initialize(table_class, column_name, column_type, file_class, dic={})
		@table_class = table_class
		@column_name = column_name
		@column_type = column_type
		@file_class = file_class
		@is_deleted = false
		self.parse(dic)
	end
	def getTableClass
		return @table_class
	end
	def setTable(table_class)
		@table_class = table_class
	end
	def parse(dic)
		puts "dic #{dic['default']&.type}"
		ast = dic["default"]
		value = dic["default"]&.source if dic["default"]&.type.to_s == "var_ref"
		@default_value = value || handle_symbol_literal_node(ast) || handle_string_literal_node(ast)
	end
end
class Index
	# belongs to model class which is active record
	attr_accessor :name, :table_name, :columns, :unique, :where, :length, :order
	def initialize(name, table_name, columns)
		@name = name
		@table_name = table_name
		@columns = columns
		@unique = false
	end
end