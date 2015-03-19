describe Importer::Sheet do

  before do
    @importer = Importer.new
    @sheet = @importer.default_sheet
  end

  it 'should respond to build' do
    @sheet.should respond_to(:build)
    @sheet.build do
      column :foo
    end
    @sheet.columns.count.should == 1
  end
  
  it 'should define columns' do
    @sheet.column(:foo)
    @sheet.columns.count.should == 1
  end
  
  it 'should find headers automatically' do
    # Define a few sample columns
    @sheet.column(:alpha)
    @sheet.column(:gamma)
    # Some dummy data
    rows = [
      ['', '', '', ''],
      ['Alpha', 'Beta', 'Gamma', 'Epsilon']
    ]
    
    # Parse it!
    @sheet.parse_header(rows).should be_true
    
    @sheet.column(:alpha).data.index.should == 0
    @sheet.column(:gamma).data.index.should == 2
    @sheet.data.start_row.should == 3
  end
  
  it 'should record an error if a column can\'t be found' do
    # Define a few sample columns
    @sheet.column(:alpha)
    @sheet.column(:gamma)
    # Some dummy data
    rows = [
      ['', '', '', ''],
      ['Bob', 'Beta', 'Gamma', 'Epsilon']
    ]
    
    # Parse it!
    @sheet.parse_header(rows).should be_false
    @importer.errors.count.should == 1
    @importer.error_summary.should =~ /unable to locate required column header/i
  end
  
  it 'should match by sheet name or number' do
    @sheet.id = 5
    @sheet.match_sheet?('foo', 3).should be_false
    @sheet.match_sheet?('foo', 4).should be_true
    
    @sheet.id = 'Sheet 5'
    @sheet.match_sheet?('Sheet', 4).should be_false
    @sheet.match_sheet?('Sheet 5', 3).should be_true
  end

end