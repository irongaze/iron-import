# GEM: iron-import

Written by Rob Morris @ Irongaze Consulting LLC (http://irongaze.com)

DESCRIPTION
-----------

Simple, versatile, reliable tabular data import.

This gem provides a set of classes to support automating import of tabular data from 
CSV/TSV, HTML, XLS and XLSX files.  Key features include defining columns, auto-detecting column order, 
pre-parsing data, validating data, filtering rows, and robust error tracking.

IMPORTANT NOTE: this gem is in flux as we work to define the best possible abstraction
for the task.  Breaking changes will be noted by increases in the minor version,
ie 0.5.0 and 0.5.1 will be compatible, but 0.6.0 will not (i.e. we follow semantic versioning).

WHO IS THIS FOR?
----------------

The Roo/Spreadsheet gems do a great job of providing general purpose spreadsheet reading.
However, using them with unreliable user submitted data requires a lot of error checking,
monkeying with data coercion, etc.  At Irongaze, we do a lot of work with growing
businesses, where Excel files are the lingua franca for all kinds of uses.  This gem 
attempts to extract years of experience building one-off importers into a simple library 
for rapid import coding.

In addition, it's quite common for the same data to be transmitted in varying formats -
Excel files, HTML files, CSV files, custom text streams...  Use iron-import to have a single
tool-set for processing any of these types of data, often without changing a line of code.

This is NOT a general-purpose tool for reading spreadsheets.  If you want access to 
cell styling, reading underlying formulas, etc., you will be better served building
a custom importer based on Roo.  But if you're looking to take a customer-uploaded CSV file,
validate and coerce values, then write each row to a database, all the while tracking
any errors encountered... well, this is the library for you!

KEY FEATURES
------------

- Simple yet robust data import and error handling using elegant builder syntax
- Import data from file, stream or string data sources
- Import XLS, XLSX, CSV and HTML tabular data
- Import custom tabular data via passed block
- Automatic column order and start row detection
- Support for optional columns and dynamic column sets
- Basic data coercion supporting string, int, float, date, bool and cents types
- Custom data coercion via passed block
- Custom data validation via passed block
- Row filtering using custom block
- Automatically track and report errors with fine-grained context
- Prefer capturing errors over raising exceptions for more robust imports

SAMPLE USAGE
------------

    # Define our importer, with three columns.  The importer will look for a row containing
    # "name"/"product", "description" and "price" (case insensitively) and automatically determine column
    # order and the starting row of the data.
    importer = Importer.build do
      column :name do
        # Provide a regex to find the header for this column
        header /(name|product)/i
      end
      column :description do
        # Columns can do custom parsing
        parse do |raw_val|
          raw_val.to_s.strip
        end
        # And custom validation
        validate do |parsed_val|
          add_error('Description too short') unless parsed_val.length > 5
        end
      end
      column :price do
        # Built in type conversion handles common cases - in this case
        # will correctly turn 2.5, "$2.50" or "2.5" into 250
        type :cents
      end
      
      # Need to skip rows?  Use a filter!  Return true to include a row when processing
      filter_rows do |row|
        row[:price] != 0 && row[:name] != 'Sample'
      end
    end
    
    # Import the provided file or stream row-by-row (if importing succeeds), automatically
    # using the proper library to read CSV data.  This same code would work
    # with XLS or XLSX files with no changes to the code.
    importer.import('/tmp/source.csv') do |row|
      puts row[:name] + ' = ' + row[:description]
    end    

    # Check for errors and do the right thing:
    importer.on_error do
      if missing_headers.any?
        # Can't find required column header(s)
        puts "Unable to locate columns: #{missing_headers}"
        
      elsif columns.any?(&:error_values?)
        # Invalid or unexpected values in one or more columns
        columns.select(&:error_values?).each do |col|
          puts "Invalid values for #{col}: #{col.error_values}"
        end
        
      else
        # General errors, dump summary report
        puts "Error(s) on import: " + error_summary
      end
    end

    # You can chain the build/import/on-error blocks for a cleaner flow:
    Importer.build do
      column :one
      column :two
    end.import(params[:uploaded_file]) do |row|
      SomeModel.create(row)
    end.on_error do
      raise "Errors found: " + error_summary
    end
    
IMPORT EXECUTION ORDER
----------------------

It can be tricky to keep track of what happens in Importer#import, so here's a quick cheat-sheet:

- Determine the **format** of stream/file to import
- Determine **import scope** (sheet/table/whatever) using Importer#scope settings, if any
- **Find column headers + start row**
- Validate presence of **required columns**
- Validate **column set** using Importer#validate_columns
- Run each row:
  - **Parse** each column's value using Column#parse or Column#type
  - **Filter the row** using Importer#filter_rows on parsed values to reject unwanted rows
  - **Calculate virtual columns** using Column#calculate
  - **Validate each parsed value** using Column#validate
  - **Validate entire row** using Importer#validate_rows

Generally, the import will stop when an error occurs, save on row processing, where each row will
be run until an error for that row is found.  The goal is to accumulate actionable info for
presentation to the end user who is uploading the file.

REQUIREMENTS
------------

Depends on the iron-extensions and iron-dsl gems for CSV and custom import formats.

Optionally requires the roo gem to support XLS and XLSX import and parsing.  

Optionally requires the nokogiri gem to support HTML import and parsing.  

Requires RSpec, nokogiri and roo to build/test.

INSTALLATION
------------

To install, simply run:

    sudo gem install iron-import
    
RVM users can skip the sudo:
  
    gem install iron-import

Then use

    require 'iron-import'
    
to require the library code.
