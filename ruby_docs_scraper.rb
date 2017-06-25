require 'httparty'
require 'nokogiri'
require 'json'
require 'yaml'
require 'pry'

# Create a Nokogiri object for a given page
def load_doc(path)
  page = HTTParty.get(path)
  
  Nokogiri::HTML(page)
end

# Scrape links from the core page
def scrape_links(parsed_page, core_path)
  links = []
  
  parsed_page.css('#class-index').css('.entries').css('a').each do |link|
    link_data = Hash.new
    
    link_data[:title] = link.text
    link_data[:path] = core_path + link.attributes['href'].value
    
    links << link_data
  end
  
  links
end

def scrape_core_page_links(core_path)
  parsed_page = load_doc(core_path)
  
  scrape_links(parsed_page, core_path)
end

# Scrape method data from a class page
def scrape_callseqs(method)
  callseqs = []
  
  method.css('.method-heading').css('.method-callseq').each do |callseq|
    callseqs << callseq.text
  end
  
  if callseqs.empty?
    method.css('.method-heading').each do |heading|
      name = heading.css('.method-name').text
      args = heading.css('.method-args').text
      
      callseqs << name + args
    end
  end
  
  callseqs
end

def scrape_description(method)
  method.css('div').css('p').map { |para| para.text }
end

def scrape_examples(method)
  method.css('div').css('.ruby').text
end

def scrape_methods(parsed_page)
  methods = []
  id_counter = 0
  
  parsed_page.css('.documentation-section').css('.method-detail').each do |method|
    method_info = Hash.new

    method_info[:id] = id_counter
    method_info[:callseqs] = scrape_callseqs(method)
    method_info[:description] = scrape_description(method)
    method_info[:examples] = scrape_examples(method)
    
    id_counter += 1
    methods << method_info
  end
  
  methods
end

def scrape_class_methods_page(path)
  parsed_page = load_doc(path)
  
  scrape_methods(parsed_page)
end

# Write method data into a YAML file
def write_method_data_yaml(link_data, methods, id)
  Dir.mkdir('data') unless Dir.exist?('data')
  
  path = "data/#{link_data[:title]}_methods.yml"
  
  data = {
    id: id,
    name: link_data[:title],
    link: link_data[:path],
    methods: methods
  }
  
  File.open(path, 'w') { |file| file.write(data.to_yaml) }
end

# Write all core method files
def write_method_files(core_path)
  core_links = scrape_core_page_links(core_path)
  id_counter = 0
  
  core_links.each do |link_data|
    methods = scrape_class_methods_page(link_data[:path])
    write_method_data_yaml(link_data, methods, id_counter) unless methods.empty?
    id_counter += 1
  end
end

core_2_4_1 = 'http://ruby-doc.org/core-2.4.1/'
write_method_files(core_2_4_1)
