require "defaulty/version"
require 'plist'
require 'open-uri'
require 'json'
require 'yaml'

require 'open-uri'
require 'uri'

# From: http://stackoverflow.com/questions/7578898/is-there-a-unified-way-to-get-content-at-a-file-or-http-uri-scheme-in-ruby
module URI
  class File < Generic
    def open(*args, &block)
      ::File.open(self.path, &block)
    end
  end

  @@schemes['FILE'] = File
end


class Defaulty
  class Domain
    attr_reader :name, :properties

    def initialize(h)
      raise "Domain needs to be initialized with a hash containing one key, the domain name" unless h.size == 1

      @name, data = h.first
      properties = data.delete('keys').map { |key, data| Property.new(key, data) } 
      @properties = Hash[ properties.map { |property| [property.name, property] } ]
    end
  end

  class Property 
    attr_reader :name, :summary, :type

    def initialize(key, data)
      @name = key
      @summary = data['summary']
      @type = data['type']
      # TODO: add more properties
    end
  end

  def self.load(*urls)
    defs = urls.map do |url|
      if github_index_url?(url)
        load_ymls_from_github(url)
      else
        load_ymls_from_path(url)
      end
    end 

    Defaulty.new(defs.flatten)
  end


  def self.domains
    `defaults domains`.split(",").map { |domain| domain.strip }
  end

  def self.defaults(domain)
    Plist::parse_xml `defaults export #{domain} -`
  end

  def self.all_defaults
    all_domains = domains + ['NSGlobalDomain']
    selected_domains = all_domains
    pairs = selected_domains.map do |domain|
      [domain, defaults(domain)]
    end
    Hash[pairs]
  end

  def write(app, options)
    domain = @domains[app]
    raise "Can't find domain for '#{app}'" unless domain
    options.each do |key, value|
      key = key.to_s
      property = domain.properties[key]
      raise "Can't find a property '#{key}' in domain '#{domain.name}'" unless property
      cmd = "defaults write #{domain.name} #{property.name} -#{property.type} #{value}"
      puts cmd
      `#{cmd}`
    end
  end

  private

  def self.github_index_url?(url)
    url =~ %r(^https://api.github.com/repos/.*/contents/?$)
  end

  def self.yml_url?(url)
    url =~ /\.yml$/ 
  end

  def self.load_ymls_from_github(contents_url)
    contents = JSON.parse(open(contents_url).read)
    yml_contents = contents.select { |f| yml_url?(f['name']) }
    yml_contents.map { |yml| load_yml(yml['download_url']) }
  end

  def self.load_ymls_from_path(contents_url)
    yml_files = Dir.glob("#{contents_url}/**/*.yml")
    yml_files.map { |yml_file| load_yml(yml_file) }
  end

  def self.load_yml(url)
    YAML.load(open(url).read)
  end

  def initialize(defs)
    domains = defs.map { |d| Domain.new(d) }
    @domains = Hash[ domains.map { |domain| [domain.name, domain] } ]
  end

end


