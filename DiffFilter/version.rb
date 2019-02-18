class Version
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
		puts "@files.length: #{@files.length}"
		puts "@activerecord_files.length: #{@activerecord_files.length}"
		@activerecord_files.each do |key, file|
			puts "#{key} #{file.getConstraints.length}"
		end
	end
	def annotate_model_class
		not_active_files =[]
		@files.values.each do |file|
			if file.upper_class_name == "ActiveRecord::Base"
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
					not_active_files.remove(file)
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
		puts "---------------columns-----------------"
		get_activerecord_files.each do |key, file|
			puts "#{key} #{file.getColumns.length}"
		end
	end
	def compare_constraints(old_version)
		newly_added_constraints = []
		@activerecord_files.each do |key, file|
			old_file = old_version.get_activerecord_files[key]
			# if the old file doesn't exist, which means it's newly created
			next unless old_file
			constraints = file.getConstraints
			old_constrants = old_file.getConstraints
			constraints.each do |column_keywords, constraint|
				if old_constrants[column_keywords] 

				else
					newly_added_constraints << constraint
				end

			end
		end
		return newly_added_constraints
	end
end