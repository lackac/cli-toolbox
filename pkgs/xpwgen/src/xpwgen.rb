require "optparse"
require "securerandom"

options = {
  source: ENV.fetch("SOURCE", "wordlist"),
  wordlist: ENV["XPWGEN_WORDLIST"],
  word_count: (ENV["WORD_COUNT"] || 4).to_i,
  max_length: ENV["MAX_LENGTH"]&.to_i,
}

OptionParser.new do |parser|
  parser.banner = "Usage: xpwgen [options] [count]"

  parser.on("--wordlist PATH", "Use a wordlist file at PATH") do |path|
    options[:wordlist] = path
  end

  parser.on("--source NAME", "Use ~/.local/share/xpwgen/NAME or XDG_DATA_HOME/xpwgen/NAME") do |name|
    options[:source] = name
  end

  parser.on("--words COUNT", Integer, "Use COUNT words per phrase") do |count|
    options[:word_count] = count
  end

  parser.on("--max-length LENGTH", Integer, "Require phrases to be at most LENGTH characters") do |length|
    options[:max_length] = length
  end
end.parse!(ARGV)

count = (ARGV.first || 1).to_i
max_tries = 50

data_home = ENV["XDG_DATA_HOME"] || File.join(Dir.home, ".local", "share")
wordlist_path = if options[:wordlist]
  File.expand_path(options[:wordlist])
else
  File.join(data_home, "xpwgen", options[:source])
end

unless File.file?(wordlist_path)
  warn "Wordlist not found: #{wordlist_path}"
  warn "Provide --wordlist PATH or place a file in #{File.join(data_home, 'xpwgen')}"
  exit 1
end

wordlist = File.readlines(wordlist_path, chomp: true).reject(&:empty?)

if wordlist.empty?
  warn "Wordlist is empty: #{wordlist_path}"
  exit 1
end

count.times do
  tries = 0

  loop do
    words = wordlist.sample(options[:word_count], random: SecureRandom)
    phrase = words.join("-")

    if options[:max_length].nil? || phrase.length <= options[:max_length]
      puts phrase
      break
    end

    tries += 1
    if tries >= max_tries
      warn "Couldn't find a phrase in #{max_tries} attempts"
      break
    end
  end
end
