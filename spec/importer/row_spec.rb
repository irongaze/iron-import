describe Importer::Row do

  before do
    @importer = Importer.new
    @row = Importer::Row.new(@importer, 5)
  end

  it 'should store and retrieve values' do
    @row.set_values(:a => 1, :b => 2)
    @row.values.should == {:a => 1, :b => 2}
  end

  it 'should allow [] access' do
    @row.set_values(:a => 1, :b => 2)
    @row[:b].should == 2
  end

  it 'should test for value presence in all columns' do
    @row.set_values(:a => 1, :b => 2)
    @row.should be_all
    @row.set_values(:a => 1, :b => nil)
    @row.should_not be_all
  end

  it 'should test for specific value\'s presence' do
    @row.set_values(:a => 1, :b => 2, :c => nil)
    @row.all?(:a, :b).should be_true
    @row.all?(:c).should be_false
  end

  it 'should be empty? with zero values' do
    @row.set_values(:a => nil, :b => nil)
    @row.should be_empty
  end
  
  it 'should not change when to_hash values are changed' do
    @row.set_values(:a => 1, :b => 2)
    hash = @row.to_hash
    hash.should == {:a => 1, :b => 2}
    hash.delete(:a)
    @row[:a].should == 1
  end

end