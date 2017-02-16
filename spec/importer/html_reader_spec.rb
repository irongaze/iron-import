describe Importer::HtmlReader do

  it 'should load a simple table' do
    importer = Importer.build do
      column :name
      column :id do
        type :int
      end
    end
    res = importer.import(SpecHelper.sample_path('simple.html'))
    importer.error_summary.should be_nil
    res.should be_true
    importer.to_a.should == [
      {:name => 'John', :id => 888},
      {:name => 'Anne', :id => 1234}
    ]
  end
  
  it 'should honor start row' do
    txt = '<table><tr><th>Notes From Clark:</th><td class="notes">Can you please send us 5 more white hooks for your display. Please rush ship this order. Thank you!</td></tr></table>'
    importer = Importer.build do
      start_row 1
      
      column :note_header do
        header /Notes From/i
      end
      column :note do
        position 2
      end
    end
    importer.import_string(txt).should be_true
    importer.data.start_row.should == 1
    importer.to_a.should == [{:note_header => 'Notes From Clark:', :note => 'Can you please send us 5 more white hooks for your display. Please rush ship this order. Thank you!'}]
  end
  
  it 'should properly expand colspan cells' do
    importer = Importer.build do
      column :one
      column :two
      column :three
    end
    res = importer.import(SpecHelper.sample_path('col-span.html'))
    importer.error_summary.should be_nil
    res.should be_true
    importer.to_a.each do |row|
      row[:one].should == 'First' unless row[:one].nil?
      row[:two].should == 'Second' unless row[:two].nil?
      row[:three].should == 'Third' unless row[:three].nil?
    end
  end
  
  it 'should limit search by scope' do
    importer = Importer.build do
      column :alpha
      column :beta
      column :gamma
    end
    res = importer.import(SpecHelper.sample_path('multi-table.html'))
    importer.error_summary.should be_nil
    res.should be_true
    importer.to_a.should == [
      {:alpha => '1', :beta => '2', :gamma => '3'},
      {:alpha => '4', :beta => '5', :gamma => '6'}
    ]

    res = importer.import(SpecHelper.sample_path('multi-table.html'), :scope => '.second table')
    importer.error_summary.should be_nil
    res.should be_true
    importer.to_a.should == [
      {:alpha => '7', :beta => '8', :gamma => '9'}
    ]
  end
  
  it 'should strip tags from cells' do
    importer = Importer.build do
      column :q1 do
        header /^Q1$/
      end
    end
    res = importer.import(SpecHelper.sample_path('scores.html'))
    importer.error_summary.should be_nil
    res.should be_true
    importer.to_a.should == [
      {:q1 => '16'},
      {:q1 => '13'}
    ]
  end
  
  it 'should treat th and td cells impartially and return in order' do
    importer = Importer.build do
      column :a
      column :b
      column :c
      column :d
    end
    res = importer.import(SpecHelper.sample_path('html-th-td.html'))
    importer.error_summary.should be_nil
    res.should be_true
    importer.to_a.should == [
      {:a => '1', :b => '2', :c => '3', :d => '4'},
      {:a => '1', :b => '2', :c => '3', :d => '4'}
    ]
  end
  
end