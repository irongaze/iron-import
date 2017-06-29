describe Importer::Error do

  before do
    @importer = Importer.new
    @row = Importer::Row.new(@importer, 5)
    @col = Importer::Column.new(@importer, :test)
  end

  it 'should capture context' do
    val = 'foo'
    err = nil
    Importer::Error.with_context(@importer, @row, @col, val) do
      err = Importer::Error.new('hi')
    end
    err.row.should == @row
    err.column.should == @col
    err.value.should == val
  end

  it 'should return error status for #with_context' do
    # Block runs fine, no error
    had_err = Importer::Error.with_context(@importer, @row, @col, 'bob') do
      false
    end
    had_err.should be_false

    # Create a new error, we should get a true
    had_err = Importer::Error.with_context(@importer, @row, @col, 'bob') do
      Importer::Error.new('hi')
    end
    had_err.should be_true
  end

end