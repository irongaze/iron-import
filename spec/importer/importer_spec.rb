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
    # Some dummy data
    rows = [
      ['Bob', 'Beta', 'Gamma', 'Epsilon']
    ]

    # Parse it!
    importer.find_header(rows).should be_false
    importer.missing_headers.should == [:alpha]
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

    importer.on_error do
      was_run = true
    end
    was_run.should be_false

    importer.add_error('An error')
    importer.on_error do
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
    Importer.build do
      column :one
      column :two
    end.import_string(csv, :format => :csv) do |rows|
      rows[:one].should == '1'
      rows[:two].should == '2'
      sum = rows[:one].to_i + rows[:two].to_i
    end
    # Just make sure we ran correctly
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
  
end