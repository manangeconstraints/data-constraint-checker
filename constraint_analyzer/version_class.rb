class Version_class
	attr_accessor  :app_dir, :commit
	def initialize(app_dir, commit)
		@app_dir = app_dir
		@commit = commit
		@files = {}
		@activerecord_files = {}
	end
	def extract_files
		if @app_dir and @commit 
			@files = read_ruby_files(@app_dir, commit)
		end
	end
	def extract_constraints
		# extract the constraints from the active record file
		@activerecord_files = @files.select{|key, x| x.is_activerecord}
		# puts"@files.length: #{@files.length}"
		# puts"@activerecord_files.length: #{@activerecord_files.length}"
		@activerecord_files.each do |key, file|
			# puts"#{key} #{file.getConstraints.length}"
			file.create_con_from_column_type
			file.create_con_from_index
			file.getConstraints.each do |k, constraint|
				# puts"\t#{constraint.column}"
			end
		end
	end
	def annotate_model_class
		not_active_files =[]
		@files.values.each do |file|
			if ["ActiveRecord::Base","Spree::Base"].include?file.upper_class_name
				file.is_activerecord = true
			else
				not_active_files << file
			end
		end
		while(true)
			length = not_active_files.length
			not_active_files.each do |file|
				key = file.upper_class_name
				if @files[key] and @files[key].is_activerecord
					file.is_activerecord = true
					not_active_files.delete(file)
				end
			end
			if not_active_files.length == length
				break
			end
		end
	end
	def get_activerecord_files
		return @activerecord_files
	end
	def print_columns
		# puts"---------------columns-----------------"
		get_activerecord_files.each do |key, file|
			# puts"#{key} #{file.getColumns.length}"
			file.getColumns.each do |key, column|
				# puts"\t#{column.column_name}"
			end
		end
	end
	def compare_constraints(old_version)
		newly_added_constraints = []
		changed_constraints = []
		existing_column_constraints = []
		new_column_constraints = []
		not_match_html_constraints = []
		@activerecord_files.each do |key, file|
			old_file = old_version.get_activerecord_files[key]
			# if the old file doesn't exist, which means it's newly created
			next unless old_file
			constraints = file.getConstraints
			old_constrants = old_file.getConstraints
			old_columns = old_file.getColumns
			constraints.each do |column_keyword, constraint|
				if old_constrants[column_keyword] 
					if !constraint.is_same(old_constrants[column_keyword])
						changed_constraints << constraint
						if not is_html_constraint_match_validate(old_constraints, column_keyword, constraint)
							not_match_html_constraints << constraint
						end
					end
				else
					newly_added_constraints << constraint
					column_name = constraint.column
					if old_columns[column_name]
						existing_column_constraints << constraint
					else
						new_column_constraints << constraint
					end
					if not is_html_constraint_match_validate(old_constraints, column_keyword, constraint)
						not_match_html_constraints << constraint
					end
				end
			end
		end
		return newly_added_constraints,changed_constraints,existing_column_constraints,new_column_constraints,not_match_html_constraints
	end
  def is_html_constraint_match_validate(old_constraints, column_keyword, constraint)
		key = column_keyword.gsub("-html", "-validate")
		key2 = column_keyword.gsub("-html", "-db")
		old_model_constraint =  old_constraints[key]
		old_db_constraint = old_constraints[key2]
		if  constraint.is_same_notype(old_model_constraint) or constraint.is_same_notype(old_db_constraint)
			return true
		end
		return false
	end
	def compare_self
		absent_cons = {}
		puts "@activerecord_files: #{@activerecord_files.length}"
		total_constraints = @activerecord_files.map{|k,v| v.getConstraints.length}.reduce(:+)
		db_cons_num = 0
		model_cons_num = 0
		mm_cons_num = 0
		@activerecord_files.each do |key, file|
			constraints = file.getConstraints
			model_cons = constraints.select{|k,v| k.include?"-validate"}
			db_cons = constraints.select{|k,v| k.include?"-db"}
			model_cons_num += model_cons.length
			db_cons_num += db_cons.length 
			db_cons.each do |k, v|
				k2 = k.gsub("-db","-validate")
				puts "k2 #{k2}"
				begin
					column_name = v.column
					column = file.getColumns[column_name]
					db_filename = column.file_class.filename
				rescue
					column_name = "nocolumn"
					db_filename = "nofile" 
				end
				unless model_cons[k2]
					absent_cons[k] = v
					v.self_print
					puts "absent: #{column_name} #{v.table} #{db_filename} #{v.class.name} #{@commit}"
				else
					v2 = model_cons[k2]
					if v.is_a?Length_constraint				
						if (v2.max_value and v.max_value  and v2.max_value != v.max_value) 
							puts "mismatch constraint max #{v.table}  #{v.max_value} #{v2.max_value} #{column_name} #{db_filename} #{@commit}" 
						end
						if (v2.min_value and v.min_value  and v2.min_value != v.min_value)
							puts "mismatch constraint min #{v.table}  #{v.min_value} #{v2.min_value} #{column_name} #{db_filename} #{@commit}"
						end
						v.self_print
					end
					if not v.is_same_notype(v2)
						puts "mismatch constraint #{db_filename} #{@commit} #{v.class.name} #{v.table} #{v.to_string} #{v2.to_string}"
						mm_cons_num += 1
					end
				end
			end
		end
		puts "total absent: #{absent_cons.size} total_constraints: #{total_constraints} model_cons_num: #{model_cons_num} db_cons_num: #{db_cons_num} mm_cons_num: #{mm_cons_num}"
	end
	def build
		self.extract_files
		self.annotate_model_class
		self.extract_constraints
		self.print_columns
	end
end