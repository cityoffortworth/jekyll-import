module JekyllImport
  module Importers
    class FW < Importer

      def self.require_deps
        JekyllImport.require_with_fallback(%w[
          nokogiri
          fileutils
          reverse_markdown
        ])
      end

      def self.specify_options(c)
        c.option 'xml_file', '--file NAME', 'The XML file to import'
        c.option 'target_dir', '--dir NAME', 'The target directory for pages'
      end

      def self.process(options)
        xml_file = options.fetch('xml_file')
        dir = options.fetch('target_dir')

        document = Nokogiri::XML(File.open(xml_file))
        document.css('Detail').each { |node| write_page(node, dir) }
      end

      def self.write_page(node, dir)
        title = node.css('content_title').text
        teaser = node.css('content_teaser').text
        excerpt = Nokogiri::HTML.fragment(teaser).css('p').text

        body = node.css('content_html').text
        body = Nokogiri::HTML.fragment(body)
        body.css('h2').first.remove
        body.css('h4').first.remove

        body = ReverseMarkdown.convert body.to_html

        header = {
          'title' => title,
          'excerpt' => excerpt,
          'date' => get_date(node, 'date_created'),
          'end_date' => get_date(node, 'end_date')
        }

        date = Date.parse(node.css('date_created').text)
        slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
        filename = File.join(dir, "#{date}-#{slug}.md")

        FileUtils.mkdir_p(dir)
        File.open(filename, "w") do |f|
          f.puts header.to_yaml
          f.puts "---\n\n"
          f.puts body
        end
      end

      def self.get_date(node, css)
        node.at_css(css) ? Time.parse(node.css(css).text).utc.to_s : nil
      end

    end
  end
end
