require 'helper'

class TestFWImporter < Test::Unit::TestCase
  should "prints titles" do
    options = {
      'xml_file' => '../FortWorthTexas.gov/_data/city-news-export-test.xml',
      'target_dir' => '_posts/test'
    }
    Importers::FW.process(options)
  end
end
