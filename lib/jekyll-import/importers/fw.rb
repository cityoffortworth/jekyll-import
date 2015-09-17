module ReverseMarkdown
  module Converters
    def self.unregister(tag_name)
      @@converters.delete(tag_name.to_sym)
    end
  end
end

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
        c.option 'omit_timestamp', '--omit_timestamp', 'Generated filenames will not have timestamps appended'
      end

      def self.process(options)
        ReverseMarkdown::Converters.unregister(:div)
        ReverseMarkdown::Converters.unregister(:table)

        xml_file = options.fetch('xml_file')
        document = Nokogiri::XML(File.open(xml_file))
        document.css('Detail').each { |node| write_page(node, options) }
      end

      def self.write_page(node, options)
        content_id = Integer(node.css('content_id').text)
        title = node.css('content_title').text
        teaser = node.css('content_teaser').text
        excerpt = Nokogiri::HTML.fragment(teaser).css('p').text

        body = node.css('content_html').text
        body = Nokogiri::HTML.fragment(body)
        body.css('h2').first.remove if body.at_css('h2')
        body.css('h4').first.remove if body.at_css('h4')

        body = ReverseMarkdown.convert(body.to_html)

        header = {
          'content_id' => content_id,
          'title' => title,
          'excerpt' => excerpt,
          'date' => get_date(node, 'date_created')
        }

        header['end_date'] = get_date(node, 'end_date') if node.at_css('end_date')

        date = Date.parse(node.css('date_created').text)
        slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
        omit_timestamp = options.fetch('omit_timestamp', false)
        dir = options.fetch('target_dir')
        filename = omit_timestamp ? File.join(dir, "#{slug}.md") : File.join(dir, "#{date}-#{slug}.md")

        FileUtils.mkdir_p(dir)
        File.open(filename, "w") do |f|
          f.puts header.to_yaml
          f.puts "---\n\n"
          f.puts body
        end
      end

      def self.get_date(node, css)
        value = node.css(css).text
        format = '%Y-%m-%dT%H:%M:%S'
        node.at_css(css) ? DateTime.parse(value).strftime(format) : nil
      end

    end
  end
end
