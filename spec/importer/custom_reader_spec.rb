describe Importer::CustomReader do

  before do
    @importer = Importer.new
  end
  
  it 'should set up correctly for on_file handling' do
    @importer.custom_reader.should be_nil
    @importer.build do
      headerless!
      on_file do |source, sheet|
        []
      end
    end
    @importer.custom_reader.should be_an(Importer::CustomReader)
    @importer.custom_reader.should be_supports_file
    @importer.custom_reader.should_not be_supports_stream
  end

  it 'should load the ICD10 test document' do
    importer = Importer.build do
      headerless!
      column :code do
        required!
      end
      column :desc do
        required!
      end

      on_file do |source, sheet|
        File.readlines(source).collect do |line|
          line.extract(/([A-TV-Z][0-9][A-Z0-9]{1,5})\s+(.*)/)
        end
      end
    end
    importer.import(SpecHelper.sample_path('icd10-custom.txt'))
    importer.error_summary.should be_nil
    importer.default_sheet.dump.should == [
      {:code => 'A000', :desc => 'Cholera due to Vibrio cholerae 01, biovar cholerae'},
      {:code => 'A001', :desc => 'Cholera due to Vibrio cholerae 01, biovar eltor'},
      {:code => 'A009', :desc => 'Cholera, unspecified'},
      {:code => 'A0100', :desc => 'Typhoid fever, unspecified'}
    ]
  end
  
  it 'should allow adding errors in custom blocks' do
    importer = Importer.build do
      headerless!
      column :code
      column :desc

      on_file do |source, sheet|
        add_error('Unable to read cause no reader')
      end
    end
    importer.import(SpecHelper.sample_path('icd10-custom.txt'))
    importer.error_summary.should include('Unable to read cause no reader')
  end
  
end