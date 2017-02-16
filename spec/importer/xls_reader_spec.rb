describe Importer::XlsReader do

  it 'should read our products sample' do
    importer = Importer.build do
      column :part_num do
        header /part/i
      end
      column :quantity do
        type :int
      end
      column :desc do
        header /description/i
      end
      column :unit_cost do
        type :cents
      end
      column :total_cost do
        type :cents
      end
    end
    importer.import(SpecHelper.sample_path('test-products.xls'))
    importer.error_summary.should be_nil
    importer.to_a.should == [
      {:part_num=>"00245",
       :quantity=>2,
       :desc=>"Washer",
       :unit_cost=>899,
       :total_cost=>1798},
      {:part_num=>"10855",
       :quantity=>4,
       :desc=>"Misc Bits",
       :unit_cost=>1000,
       :total_cost=>4000},
      {:part_num=>"19880-2",
       :quantity=>3,
       :desc=>"A duck!",
       :unit_cost=>10731,
       :total_cost=>32193},
      {:part_num=>"18098-8",
       :quantity=>1,
       :desc=>"Tuesday",
       :unit_cost=>5500,
       :total_cost=>5500}
    ]
  end

  it 'should search by scope' do
    importer = Importer.build do
      column :sheet do
        type :int
      end
      column :val
      
      filter do |row|
        row.all?
      end
    end

    # Default case
    res = importer.import(SpecHelper.sample_path('3-sheets.xls'))
    importer.format.should == :xls
    importer.error_summary.should be_nil
    importer.to_a.should == [{:sheet => 1, :val => 'Monkey'}]

    # Pass scope to import
    res = importer.import(SpecHelper.sample_path('3-sheets.xls'), :scope => 2)
    importer.error_summary.should be_nil
    importer.to_a.should == [{:sheet => 2, :val => 'Rhino'}]

    # Define scope on importer
    importer.scope :xls, 'Sheet 3'
    res = importer.import(SpecHelper.sample_path('3-sheets.xls'))
    importer.error_summary.should be_nil
    importer.to_a.should == [{:sheet => 3, :val => 'Ant'}]
  end
  
end