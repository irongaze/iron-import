describe Importer::CsvReader do

  before do
    @importer = Importer.new
    @reader = Importer::CsvReader.new(@importer)
  end
  
  it 'should convert to standard newlines' do
    importer = Importer.build do
      headerless!
      column :number do
        type :integer
      end
      column :string do
        type :string
      end
    end      
    importer.import_string("1,\"foo\nbar\"\r\n2,hi\r3,yo").should be_true
    importer.to_a.should == [
      {:number => 1, :string => "foo\nbar"},
      {:number => 2, :string => "hi"},
      {:number => 3, :string => "yo"}
    ]
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
    importer.to_a.should == [
      {:number => 123, :string => 'Abc', :date => Date.new(1977,5,13), :cost => 899},
      {:number => nil, :string => nil, :date => nil, :cost => nil},
      {:number => 5, :string => 'String with end spaces', :date => Date.new(2004,2,1), :cost => 1000}
    ]
  end
  
  it 'should auto-detect tab-separated data' do
    @reader.load(SpecHelper.sample_path('sprouts.tsv')) do |rows|
      rows.count.should == 43
      rows.first.count.should == 5
    end
  end
  
  it 'should fail on WSM sample data' do
    importer = Importer.build do
      column :company_name do
        optional!
      end
      virtual_column :company do
        calculate do |row|
          if column(:company_name).present?
            row[:company_name]
          else
            [row[:store_code], row[:store_num]].list_join(', ')
          end
        end
      end
      column :store_code do
        header /code$/i
        optional!
      end
      column :store_num do
        optional!
        header /num(ber)?$/i
      end
      virtual_column :store do
        calculate do |row|
          Store.find_by_upc(row[:upc])
        end
      end
      column :buyer_name do
        optional!
      end
      column :buyer_email do
        optional!
        header /buyer\s*email/i
        validate do |val|
          val.match? /^\s*([a-z0-9_\-\+\.]+@[a-z0-9\.\-]+\.[a-z]+)(,\s*[a-z0-9_\-\+\.]+@[a-z0-9\.\-]+\.[a-z]+)*\s*$/i
        end
      end
      column :rep_email do
        optional!
        header /^(sales\s*)?rep\s*email/i
        validate do |val|
          val.match? /^\s*([a-z0-9_\-\+\.]+@[a-z0-9\.\-]+\.[a-z]+)(,\s*[a-z0-9_\-\+\.]+@[a-z0-9\.\-]+\.[a-z]+)*\s*$/i
        end
      end
      column :regional do
        optional!
        type :bool
      end

      # We need a company name column if none passed in
      validate_columns do |cols|
        keys = cols.collect(&:key)
        has_company = keys.include?(:company_name)
        has_company && (keys.include?(:store_num) || keys.include?(:store_code))
      end

      # Only pay attention to rows with a store num or code
      # filter_rows do |row|
      #   row[:store_num].present? || row[:store_code].present?
      # end
      
      # Make sure rows are valid
      validate_rows do |row|
        add_error("Unable to locate specified company") unless row[:company].present?
        add_error("Unable to locate specified store") unless row[:store].present?
      end
    end
    importer.import(SpecHelper.sample_path('wsm-data.csv')).should be_false
    importer.errors.first.to_s.should == "Unable to locate required column headers!"
  end
  
end