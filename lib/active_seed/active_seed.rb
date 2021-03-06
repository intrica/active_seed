require "csv"

module ActiveSeed
  def self.seed_csv(modelname, filename)
    data = CSV.read(filename)
    if data.size < 2
      puts "No data found in file " << filename
      return
    end
    header = data[0];
    processed_header = Array.new
    evaluations = Array.new
    statics = Array.new
    header.each do |h|
      # Check if the header field has an assignment
      if h.include? "="
        c = h.split "="
        h = c[0] # Replace the header with just the field name
        c.delete_at(0) # Remove the field name
        evaluation = c.join("=") # Rejoin the rest of the evaluation (if there was another =)
        # If there is no question mark in the evaluation string then we set this column to be
        # static.
        unless evaluation.include? "?"
          statics.push(h + "=" + evaluation)
        else
          processed_header.push(h)
          evaluations.push(evaluation)
        end
      else
        evaluations.push(nil)
        processed_header.push(h)
      end
    end
    header = processed_header
    data.delete_at(0);
    puts "Seeding " + data.size.to_s + " record" + (data.size > 1 ? "s" : "")
    line = 1
    data.each do |d|
      line+=1
      if d.size == header.size
        code = "model = " + modelname + ".new\n"
        for count in 0..(header.size - 1) do
          unless (header[count].strip == "nil")
            value = d[count]
            value = "" if value.nil?
            value = "'" + value.strip.gsub(/'/, "\\\\'") + "'" 
            if evaluations[count].nil?
              assignment = value
            else
	      assignment = evaluations[count].gsub(/\?+/) do |s|
	        s.size == 2 ? "?" : value 
	      end
            end
            code += "model." + header[count].strip + "=" + assignment + "\n" 
          end
        end
        # Add in the statics
        statics.each do |s|
          code += "model." + s + "\n"
        end
        code += "unless model.save\n"
        code += "ActiveSeed::print_errors(model.errors, " + line.to_s + ")"
        code += "end\n"
        eval code
        #puts (line - 1).to_s + "/" + data.size.to_s
      else
        puts "Skipping line " + line.to_s + " with mismatch in number of fields (" + d.size.to_s + ")"
      end
    end
    puts " Done"
  end

  def self.print_errors(errors, line)
    puts "\nThere were errors on line " + line.to_s
    errors.each do |e|
      puts e.to_s
    end
  end

  def seed(set)
    set_file = File.join(::Rails.root.to_s, "db", "active_seed", set + ".yml")
    if !File.exists?(set_file)
      puts "Set file doesn't exist: " << set_file
      return
    end
    puts "Seeding from set '" + set + "'"
    fixture_list = YAML::load_file(set_file)
    fixture_list.each do |model, sf|
      seed_file = File.join(::Rails.root.to_s, "db", "active_seed", "data", sf + ".csv")
      if !File.exists?(seed_file)
        puts "Seed file doesn't exist: " << seed_file
      else
        puts "Seeding '" + seed_file + "'..."
        ActiveSeed::seed_csv(model, seed_file)
      end
    end
  end

  module_function :seed
end
