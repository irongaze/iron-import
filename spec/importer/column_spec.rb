describe Importer::Column do

  before do
    @importer = Importer.new
    @col = Importer::Column.new(@importer, :test)
    @row = Importer::Row.new(@importer, 1)
  end

  it 'should respond to build' do
    @col.should respond_to(:build)
    @col.build do
      type :cents
    end
    @col.type.should == :cents
  end
  
  it 'should convert position strings to indexes' do
    {
      'A' => 0,
      'C' => 2,
      'AA' => 26,
      'BAA' => 2*26*26 + 26
    }.each_pair do |pos, index|
      Importer::Column.pos_to_index(pos).should == index
    end
  end
  
  it 'should convert position ints to position codes' do
    {
      0 => 'A',
      25 => 'Z',
      26 => 'AA',
      2*26*26 + 26 + 3 => 'BAD'
    }.each_pair do |index, pos|
      Importer::Column.index_to_pos(index).should == pos
    end
  end
  
  it 'should accept both int and string positions, and convert them to an index' do
    {
      'A' => 0,
      5 => 4,
      'Z' => 25
    }.each_pair do |pos, index|
      @col.position = pos
      @col.fixed_index.should == index
    end
  end
  
  it 'should put a pretty output on conversion to string' do
    @col.data.index = 3
    @col.to_s.should == 'Column D'
  end
  
  it 'should match by key by default' do
    ['Test', 'test', '  TEST  '].each do |header|
      @col.match_header?(header, 888).should be_true
    end
    
    ['', nil, 'Foo', 'Testy'].each do |header|
      @col.match_header?(header, 888).should be_false
    end
  end
  
  it 'should default to string type' do
    @col.type.should == :string
  end
  
  it 'should match by position if position is specified' do
    @col.position 'B'
    @col.match_header?('junk', 1).should be_true
    @col.match_header?('junk', 2).should be_false
  end
  
  it 'should match custom header matchers' do
    {
      /(alpha|beta)/ => { 'alphabet' => true, 'beta  X' => true, 'gamma' => false },
      /^test.$/i => { 'Testy' => true, 'test?' => true, 'notest' => false }
    }.each_pair do |matcher, tests|
      @col.header matcher
      tests.each_pair do |val, res|
        @col.match_header?(val, 1234).should == res
      end
    end
  end
  
  it 'should properly apply custom parsers' do
    @col.parse_value(@row, 5).should == 5
    @col.parse do |raw|
      raw.to_i + 2
    end
    @col.parse_value(@row, 5).should == 7
  end
  
  it 'should record exceptions during parsing as errors' do
    @col.parse do |raw|
      raise 'nope'
    end
    @importer.has_errors?.should be_false
    @col.parse_value(@row, 5).should be_nil
    @importer.has_errors?.should be_true
  end
  
  it 'should allow custom validation' do
    @col.validate do |val|
      raise 'nope' if val != 5
    end
    @importer.has_errors?.should be_false
    @col.validate_value(@row, 5).should be_true
    @importer.has_errors?.should be_false
    @col.validate_value(@row, 4).should be_false
    @importer.has_errors?.should be_true
  end
  
end