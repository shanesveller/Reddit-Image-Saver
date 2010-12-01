#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'uri'
require 'fileutils'
require 'json'
require 'optparse'

##########################################################################
####################### YOU CAN EDIT THIS PART ###########################
##########################################################################

# Put your favorite Reddits here
reddits = ['Pics', 'WTF'] 

# Desired sorting
sort_type = 'hot' # hot, new, controversial, top

# Folder to save pictures to
dir = 'Saved Reddit Pics'

# Maximum image links to fetch
limit = 20

##########################################################################
#################### DONT EDIT ANYTHING PAST HERE ########################
##########################################################################

# Holds command-line arguments parsed with OptionParser
# Also holds default values pulled from above
options = {
  :limit => limit,
  :output_dir => dir,
  :sort => sort_type,
  :reddits => reddits
}

# Adapted from examples at http://ruby.about.com/od/advancedruby/a/optionparser2.htm
optparse = OptionParser.new do |opts|
  # Syntax is approximately:
  # opts.on(single letter switch, word-length switch, class to typecast to OR a list of acceptable values, help text)
  # When using a class to typecast to, some rudimentary type-checking is put into place and exceptions will be raised
  # but are not particularly descriptive by default, so the output for bad values could be improved significantly.
  # Example:
  # ./reddit_image_save.rb -l abc
  # ./reddit_image_save.rb:61:in `<main>': invalid argument: -l abc (OptionParser::InvalidArgument)

  opts.on( '-l', '--limit LIMIT', Integer, 'Maximum number of images to download') do |limit|
    options[:limit] = limit
  end
  opts.on( '-o', '--output-dir DIR', String, 'Directory to save to') do |dir|
    options[:output_dir] = dir
  end
  opts.on( '-r', '--reddits a,b,c', Array, 'Comma-separated list of subreddits to download from') do |reddits|
    options[:reddits] = reddits
  end
  opts.on( '-s', '--sort SORT', [:hot, :new, :controversial, :top], 'Reddit sort style (choose from: hot, new, controversial, top)') do |sort|
    options[:sort] = sort
  end
  opts.on( '-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

optparse.parse!

# Generate custom Reddit URL
def generate_custom_url(reddit_list, sort, limit)
  "http://www.reddit.com/r/#{reddit_list.sort.join('+')}/#{sort}.json?limit=#{limit}"
end

custom_url = generate_custom_url(options[:reddits], options[:sort], options[:limit])
puts "Your Personal URL:  #{custom_url.gsub('.json', '')}\n"
puts "--------------------#{print '-' * custom_url.length}"


# Get source of page
def get_page_source(page_url)
  url = URI.parse(page_url)
  req = Net::HTTP::Get.new(url.path)
  Net::HTTP.start(url.host, url.port) do |http|
    http.request(req)
  end
end
res = get_page_source(custom_url)

# Add URLs and Title to hash
urls = {}
doc = JSON.parse(res.body)
doc['data']['children'].each do |link|
  urls[link['data']['title']] = link['data']['url']
end

# Fix ugly imgur URLs
urls.each_pair do |name, url|
  # imgur.com -> i.imgur.com
  if url =~ /^((http:\/\/)|(www))+imgur\.com.*$/
    url.insert(url.index(/(?i)(imgur\.com).*$/), 'i.')

    # i.imgur.com/1234 -> i.imgur.com/1234.jpg
    unless url =~ /^.*\.(?i)((bmp)|(gif)|(jpeg)|(jpg)|(png)|(tiff))$/
      url.concat(".jpg")
    end
  end
end

def is_picture?(file)
  valid = true
  valid = false if file =~ /^.+\.(?i)((bmp)|(gif)|(jpeg)|(jpg)|(png)|(tiff))$/
  valid = true  if file =~ /^.+\.(?i)(php)/
  valid
end

# Remove non-pictures
urls.reject! do |name, url|
  is_picture?(url)
end


# Make directory for pictures
FileUtils.mkdir_p options[:output_dir]


# Follow redirects
def fetch(uri_str, limit = 10)
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0
  response = Net::HTTP.get_response(URI.parse(uri_str))
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end


# Make file names safe
def sanitize(s)
  sani = ""
  s.each_byte do |c|
    if (c == 32 || (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122))
      sani += c.chr
    end
  end
  sani.gsub!(' ', '_')
  sani
end


def download_file(url, path)
  response = fetch(url)
  Net::HTTP.start(URI.parse(url).host) do |http|
    ext = url.match(/\.([^\.]+)$/).to_a.last
    open(path, 'w') do |file|
      file.write(response.body)
    end
  end
end


# Download files
urls.each_pair do |name, url|
    puts "Downloading: #{name}\n\t#{url}\n\n"
    ext = url.match(/\.([^\.]+)$/).to_a.last
    unless File.exist?("#{options[:output_dir]}/#{sanitize(name)}.#{ext.downcase}")
      download_file(url, "#{options[:output_dir]}/#{sanitize(name)}.#{ext.downcase}")
    end
end

puts 'Downloading Complete'
