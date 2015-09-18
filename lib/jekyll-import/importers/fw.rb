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
        c.option 'remove_h1', '--remove_h1', 'Remove H1 tag from content'
        c.option 'remove_datestamp_p', '--remove_datestamp_p', 'Remove p tag with id=datestamp'
        c.option 'omit_content_types', '--omit_content_types NUMBERS', 'Filter out given list of comma separated content type values'
      end

      def self.process(options)
        ReverseMarkdown::Converters.unregister(:div)
        ReverseMarkdown::Converters.unregister(:table)

        xml_file = options.fetch('xml_file')
        document = Nokogiri::XML(File.open(xml_file))
        detail_nodes = document.css('Detail')

        omit_content_types = options.fetch('omit_content_types', nil)
        if !omit_content_types.nil?
          types_to_omit = omit_content_types.chomp.split(/,/).map(&:to_s)
          detail_nodes = document.css('Detail').select do |n|
            !attribute_has_value?(n, 'content_type') || !types_to_omit.include?(n.attr('content_type'))
          end
        end

        detail_nodes.each { |node| write_page(node, options) }
      end

      def self.write_page(node, options)
        content_id = Integer(node.css('content_id').text)
        title = node.css('content_title').text
        teaser = node.css('content_teaser').text
        excerpt = Nokogiri::HTML.fragment(teaser).css('p').text

        body = node.css('content_html').text
        body = Nokogiri::HTML.fragment(body)

        remove_h1 = options.fetch('remove_h1', false)
        body.css('h1').first.remove if remove_h1 && body.at_css('h1')

        remove_datestamp_p = options.fetch('remove_datestamp_p', false)
        body.css('p#datestamp').first.remove if remove_datestamp_p && body.at_css('p#datestamp')

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
        header['updated'] = node.attr('last_edit_date') if attribute_has_value?(node, 'last_edit_date')
        header['thumbnail'] = "//fortworthtexas.gov/#{node.attr('image')}" if attribute_has_value?(node, 'image')

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

      def self.attribute_has_value?(node, key)
         !node.attr(key).nil? && !node.attr(key).empty?
      end
    end
  end
end
