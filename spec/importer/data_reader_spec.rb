describe Importer::DataReader do

  before do
    @importer = Importer.new
    @reader = Importer::DataReader.new(@importer, :test)
  end

  it 'should parse integers' do
    {
      '1234' => 1234,
      '-2' => -2,
      '5.00' => 5,
      '2.5.00' => nil,
      'foo' => nil,
      '4 ducks' => nil,
      '2-4' => nil,
      '' => nil,
      55 => 55,
      3.0 => 3
    }.each_pair do |val, res|
      @reader.parse_value(val, :integer).should === res
    end
  end
  
  it 'should parse floats' do
    {
      '1.256' => 1.256,
      '4.22.00' => nil,
      '-20.3' => -20.3,
      '5.00' => 5.0,
      'foo' => nil,
      '' => nil,
      55 => 55.0,
      '3' => 3.0
    }.each_pair do |val, res|
      @reader.parse_value(val, :float).should === res
    end
  end
  
  it 'should parse strings' do
    {
      'blah' => 'blah',
      " spaces \t" => 'spaces',
      '' => nil,
      255 => '255',
      -1.5 => '-1.5',
      10.0 => '10'
    }.each_pair do |val, res|
      @reader.parse_value(val, :string).should === res
    end
  end
  
  it 'should parse cents' do
    {
      '$123.00' => 12300,
      '9.95' => 995,
      '5' => 500,
      '04 ' => 400,
      '0.5' => 50,
      '-95' => -9500,
      52 => 5200,
      1.0 => 100,
      1.25 => 125
    }.each_pair do |val, res|
      @reader.parse_value(val, :cents).should === res
    end
  end
  
  it 'should parse dates' do
    {
      '1/5/73' => Date.new(1973,1,5),
      '05/30/01' => Date.new(2001,5,30),
      '2005-12-10' => Date.new(2005,12,10),
      '4/10/14 22:28' => Date.new(2014,4,10),
      '5/10/2014, 10:28:07 PM' => Date.new(2014,5,10),
      Date.new(2000,4,1) => Date.new(2000,4,1)
    }.each_pair do |val, res|
      @reader.parse_value(val, :date).should === res
    end
  end
  
  it 'should build an instance based on format' do
    Importer::DataReader.for_format(@importer, :csv).should be_a(Importer::CsvReader)
    Importer::DataReader.for_format(@importer, :xls).should be_a(Importer::XlsReader)
    Importer::DataReader.for_format(@importer, :xlsx).should be_a(Importer::XlsxReader)
    Importer::DataReader.for_format(@importer, :html).should be_a(Importer::HtmlReader)
    Importer::DataReader.for_format(@importer, :foo).should be_nil
  end
  
  it 'should build an instance based on a path' do
    Importer::DataReader.for_path(@importer, '/tmp/foo.csv').should be_a(Importer::CsvReader)
    Importer::DataReader.for_path(@importer, 'BAR.XLS').should be_a(Importer::XlsReader)
    Importer::DataReader.for_path(@importer, '/tmp/nog_bog.xlsx').should be_a(Importer::XlsxReader)
    Importer::DataReader.for_path(@importer, '/tmp/nog_bog.htm').should be_a(Importer::HtmlReader)
    Importer::DataReader.for_path(@importer, '/tmp/tim.txt.html').should be_a(Importer::HtmlReader)
    Importer::DataReader.for_path(@importer, '/tmp/blinkin.bmp').should be_nil
  end
  
  it 'should build an instance based on stream' do
    Importer::DataReader.for_stream(@importer, double(original_filename: "nanodrop.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")).should be_a(Importer::XlsxReader)
  end
  
end
