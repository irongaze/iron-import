describe Importer do

  it 'should respond to build' do
    Importer.should respond_to(:build)
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
  
end