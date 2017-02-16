describe Importer::XlsxReader do

  it 'should load our nanodrop sample' do
    importer = Importer.build do
      column :sample_id do
        validate do |val|
          raise 'Invalid ID' unless val.match(/[0-9]{3,}\.[0-9]\z/)
        end
      end
      column :a260 do
        type :float
      end
      column :a280 do
        type :float
      end
      column :factor do
        type :integer
      end
      
      # Skip empty rows
      filter do |row|
        row.all?
      end
    end
    res = importer.import(SpecHelper.sample_path('nanodrop.xlsx'))
    importer.error_summary.should be_nil
    res.should be_true
    importer.to_a.should == [
      {:sample_id => 'Windsor_buccal_500.1', :a260 => 2.574, :a280 => 1.277, :factor => 50},
      {:sample_id => 'Weston_fecal_206.2', :a260 => 0.746, :a280 => 0.351, :factor => 50}
    ]
  end
  
end