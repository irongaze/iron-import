describe Importer::CsvReader do

  before do
    @importer = Importer.new
    @reader = Importer::CsvReader.new(@importer)
  end
  
  it 'should load our simple CSV data' do
    importer = Importer.build do
      column :number do
        type :integer
      end
      column :string do
        type :string
      end
      column :date do
        type :date
      end
      column :cost do
        type :cents
      end
    end
    importer.import(SpecHelper.sample_path('simple.csv')).should be_true
    importer.default_sheet.dump.should == [
      {:number => 123, :string => 'Abc', :date => Date.new(1977,5,13), :cost => 899},
      {:number => nil, :string => nil, :date => nil, :cost => nil},
      {:number => 5, :string => 'String with end spaces', :date => Date.new(2004,2,1), :cost => 1000}
    ]
  end
  
end