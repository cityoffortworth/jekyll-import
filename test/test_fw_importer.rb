require 'helper'

class TestFWImporter < Test::Unit::TestCase
  should "produces pages from xml" do
    options = {
      'xml_file' => 'test/fixtures/fw.xml',
      'target_dir' => '_posts/test'
    }
    Importers::FW.process(options)
  end
end
