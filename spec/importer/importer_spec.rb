describe Importer do

  it 'should respond to build' do
    Importer.should respond_to(:build)
    importer = Importer.build do
      column :foo
    end
    importer.columns.count.should == 1
  end
  
  it 'should set single search scopes' do
    importer = Importer.build do
      scope :xls, 'Sheet 2'
    end
    importer.scopes.should == { :xls => ['Sheet 2'] }
  end
  
  it 'should set multiple search scopes' do
    importer = Importer.build do
      scopes :xls => [1, 'Sheet 2'],
        :html => 'table.funny'
    end
    importer.scopes.should == { :xls => [1, 'Sheet 2'], :html => ['table.funny'] }
  end
  
  it 'should find headers automatically' do
    # Define a few sample columns
    importer = Importer.new
    importer.column(:alpha)
    importer.column(:gamma)
    # Some dummy data
    rows = [
      ['', '', '', ''],
      ['Alpha', 'Beta', 'Gamma', 'Epsilon']
    ]

    # Parse it!
    importer.find_header(rows).should be_true

    importer.column(:alpha).data.index.should == 0
    importer.column(:gamma).data.index.should == 2
    importer.data.start_row.should == 3
  end
  
  it 'should report missing columns' do
    # Define a few sample columns
    importer = Importer.new
    importer.column(:alpha)
    importer.column(:gamma)
    importer.column(:optional, :optional => true)
    # Some dummy data
    rows = [
      ['Bob', 'Beta', 'Gamma', 'Epsilon']
    ]

    # Parse it!
    importer.find_header(rows).should be_false
    importer.missing_headers.should == [:alpha]
  end

  it 'should succeed when missing optional columns' do
    # Define a few sample columns
    importer = Importer.new
    importer.column(:alpha).optional!
    importer.column(:beta)
    importer.column(:gamma)
    # Some dummy data
    rows = [
      ['Bob', 'Beta', 'Gamma', 'Epsilon']
    ]

    # Parse it!
    importer.find_header(rows).should be_true
    importer.missing_headers.should be_empty
  end

  it 'should calculate virtual columns' do
    importer = Importer.build do
      column :num, :type => :int
      virtual_column :summary do
        calculate do |row|
          "Value = #{row[:num]}"
        end
      end
    end
    
    importer.import_string("num\n1\n2")
    importer.error_summary.should be_nil
    importer.column(:summary).to_a.should == ['Value = 1', 'Value = 2']
  end
  
  it 'should honor type before applying custom parsers' do
    importer = Importer.new
    importer.column(:alpha) do
      parse do |raw|
        raw
      end
    end

    importer.import_string("alpha\n1.0\n1.5")
    importer.to_a.should == [{:alpha => '1.0'}, {:alpha => '1.5'}]

    importer.column(:alpha).type :float
    importer.import_string("alpha\n1.0\n1.5")
    importer.to_a.should == [{:alpha => 1.0}, {:alpha => 1.5}]
  end
  
  it 'should support row-based validation' do
    importer = Importer.build do
      column :a, :type => :int
      column :b, :type => :int
      
      validate_rows do |row|
        row[:a] + row[:b] == 5
      end
    end
    
    importer.import_string("a,b\n1,4\n6,-1\n7,0\n1,1")
    importer.errors.count.should == 2
  end
  
  it 'should support column order/presence validation' do
    # Build an importer with optional columns
    importer = Importer.new
    importer.column(:alpha).optional!
    importer.column(:beta).optional!
    importer.column(:gamma)
    # Set up a column validator
    importer.validate_columns do |cols|
      cols = cols.collect(&:key)
      cols.sort == [:alpha, :gamma] || cols.sort == [:beta, :gamma]
    end

    # Missing required column
    importer.find_header([['Alpha', 'Beta', 'Epsilon']]).should be_false
    # Missing both optional
    importer.find_header([['Bob', 'Gamma', 'Epsilon']]).should be_false
    # Required + single optional
    importer.find_header([['Bob', 'Gamma', 'Alpha']]).should be_true
    importer.find_header([['Bob', 'Gamma', 'Beta']]).should be_true
    # Required + both optional
    importer.find_header([['Alpha', 'Gamma', 'Beta']]).should be_true
  end

  it 'should capture errors' do
    importer = Importer.build do
      column :foo
    end
    importer.add_error('An error')
    importer.has_errors?.should be_true
    importer.errors.count.should == 1
  end
  
  it 'should run conditional code when errors are present' do
    importer = Importer.build do
      column :foo
    end

    was_run = false
    importer.add_error('An error')
    importer.on_error do
      was_run = true
    end
    was_run.should be_true
  end
  
  it 'should run conditional code when successful' do
    importer = Importer.build do
      column :foo
    end

    was_run = false
    importer.import_string("foo\n1")
    importer.has_errors?.should be_false
    importer.on_success do
      was_run = true
    end
    was_run.should be_true
  end
  
  it 'should import a test csv file' do
    importer = Importer.build do
      column :number
      column :string
      column :date
      column :cost
    end
    importer.import(SpecHelper.sample_path('simple.csv')).should be_true
    count = 0
    found = false
    importer.process do |row|
      count += 1
      if row.line == 4
        found = true
        row[:date].should == '2004-02-01'
      end
    end
    found.should be_true
    count.should == 3
  end
  
  it 'should import a string' do
    sum = 0
    csv = "one,two\n1,2"
    importer = Importer.build do
      column :one
      column :two
    end.import_string(csv, :format => :csv) do |rows|
      rows[:one].should == '1'
      rows[:two].should == '2'
      sum = rows[:one].to_i + rows[:two].to_i
    end
    # Just make sure we ran correctly
    importer.column(:one).to_s.should == 'One Column'
    sum.should == 3
  end
  
  it 'should pick the proper format based on content' do
    importer = Importer.build do
      column :one
      column :two
    end
    importer.format.should be_nil
    importer.import_string("one,two\n1,2")
    importer.format.should == :csv
    importer.import_string("<div><table><tr><td>one</td></tr></table></div>")
    importer.format.should == :html
  end

  it 'should capture errors with context' do
    sum = 0
    csv = "one,two,three\n1,2,X\n1,,3"
    importer = Importer.build do
      column :one
      column :two do
        validate do |val|
          val.to_i == 2
        end
      end
      column :three do
        validate do |val|
          add_error('Invalid value') unless val.to_i > 0
        end
      end
    end
    importer.import_string(csv)
    
    # Just make sure we ran correctly
    importer.errors.count.should == 2
    importer.column(:two).errors.count.should == 1
    importer.column(:three).errors.count.should == 1
    importer.column(:three).error_values.should == ['X']
    map = importer.rows.first.error_map
    map[:two].should be_nil
    map[:three].should be_a(Importer::Error)
  end
  
  it 'should import properly when optional columns are missing' do
    csv = "one,two\n1,2\n1,"
    importer = Importer.build do
      column :one
      column :two do
        validate do |val|
          val.to_i == 2
        end
      end
      column :three do
        optional!
        validate do |val|
          add_error('Invalid value') unless val.to_i > 0
        end
      end
    end
    importer.import_string(csv)
    
    importer.found_columns.count.should == 2
  end
  
  it 'should search multiple sheets to find header' do
    importer = Importer.build do
      column :date do
        type :date
      end
      column :order
    end
    importer.import(SpecHelper.sample_path('2-sheets.xlsx')).should be_true
    importer.errors.count.should == 0
    importer.to_a.should == [{:order => '223300', :date => '1973-01-02'.to_date}]
  end
  
  it 'should find the right reader for a given format + path/stream' do
    importer = Importer.build
    importer.find_reader('foo.xls').class.should == Importer::XlsReader
    importer.find_reader('foo.text', :csv).class.should == Importer::CsvReader
    importer.find_reader('/bob/page.html').class.should == Importer::HtmlReader
    custom = Importer::CustomReader.new(importer)
    importer.find_reader('foo.text', nil, custom).class.should == Importer::CustomReader
  end

  it 'should allow reading raw row values' do
    rows = Importer.read_lines(2, SpecHelper.sample_path('2-sheets.xlsx'), :scope => 'Sheet 2')
    rows.count.should == 2
    rows.first.should == ['Table 1', nil]
    rows.last.should == ['Order', 'Date']
  end
  
  it 'should allow reading raw row values when using a custom reader' do
    custom = lambda {|source|
      File.readlines(source).collect do |line|
        line.extract(/([A-TV-Z][0-9][A-Z0-9]{1,5})\s+(.*)/)
      end
    }
    rows = Importer.read_lines(3, SpecHelper.sample_path('icd10-custom.txt'), :on_file => custom)
    rows.should == [
      ['A000', 'Cholera due to Vibrio cholerae 01, biovar cholerae'],
      ['A001', 'Cholera due to Vibrio cholerae 01, biovar eltor'],
      ['A009', 'Cholera, unspecified']
    ]
  end
  
  it 'should rewind stream after reading' do
    stream = File.open(SpecHelper.sample_path('2-sheets.xlsx'))
    stream.pos.should == 0
    rows = Importer.read_lines(2, stream, :scope => 'Sheet 2')
    stream.pos.should == 0
  end
  
  it 'should report an error when all rows are filtered' do
    importer = Importer.build do
      column :num, :type => :int
      filter do |row|
        row[:num] < 50
      end
    end

    importer.import_string("num\n1\n2")
    importer.error_summary.should be_nil
    
    importer.import_string("num\n100\n101")
    importer.error_summary.should_not be_nil
    importer.error_summary.should include('No unfiltered rows found')
  end
  
  it 'should not report an error when all rows filtered but #allow_empty! set' do
    importer = Importer.build do
      allow_empty!
      column :num, :type => :int
      filter do |row|
        row[:num] < 50
      end
    end
    
    importer.import_string("num\n100\n101")
    importer.error_summary.should be_nil
  end
  
end