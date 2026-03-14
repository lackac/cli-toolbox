require "forwardable"
require "json"
require "minitest"
require "net/http"
require "open-uri"
require "time"

require "epub/parser"

Cache = {}

class Boox2Readwise
  attr_reader :path, :book, :highlights

  def initialize(path)
    @path = path
    @text = File.read(path)
    parse_book
    @highlights = Highlight.parse(@text)
  end

  def readwise_payload
    {
      highlights: highlights.map { |highlight| book.to_readwise.merge(highlight.to_readwise) },
    }
  end

  def push_to_readwise
    uri = URI("https://readwise.io/api/v2/highlights/")
    headers = {
      "Authorization" => "Token #{ENV.fetch("READWISE_TOKEN")}",
      "Content-Type" => "application/json",
    }
    response = Net::HTTP.post(uri, JSON.dump(readwise_payload), headers)

    case response
    when Net::HTTPSuccess
      puts response.body
    else
      fail response.body
    end
  end

  def clean
    File.unlink(path)
    dir = File.dirname(path)
    Dir.rmdir(dir) if Dir.empty?(dir)
  end

  private

  def parse_book
    if @text =~ /\AReading Notes \| <<([^>]*)>>/
      book_path = File.expand_path("../../#{$1}.epub", path)
      @book = Book.new(book_path)
    else
      fail Book::ParseError, "Can't find file name in text"
    end
  end

  class Book
    class ParseError < RuntimeError; end

    include EPUB::Book::Features

    def initialize(epub_path)
      EPUB::Parser.parse(epub_path, book: self)
    rescue StandardError => e
      fail ParseError, e.message
    end

    def author
      metadata.creators.map(&:content).join(", ")
    end

    def title
      super.sub(/ *\(.*\)$/, "")
    end

    def image_url
      @image_url ||= begin
        Cache.fetch("cover-#{metadata.unique_identifier}") do |key|
          books_api_res = JSON.parse(
            URI.open(
              "https://www.googleapis.com/books/v1/volumes?q=#{google_books_query}&key=#{ENV.fetch("GOOGLE_BOOKS_API_KEY")}"
            ).read
          )
          Cache[key] = books_api_res["items"][0]["volumeInfo"]["imageLinks"]["thumbnail"]
        end
      end
    end

    def to_readwise
      {
        category: "books",
        title: title,
        author: author,
        image_url: image_url,
      }.compact
    end

    private

    def google_books_query
      isbn = [
        metadata.unique_identifier&.content&.sub(/^urn:isbn:/, ""),
        metadata.unique_identifier&.id&.sub(/^e/, ""),
        metadata.sources.first&.content&.sub(/^urn:isbn:/, ""),
      ].find { |value| value && value.delete("-") =~ /^(?:\d{10}|\d{13})$/ }

      if isbn
        "isbn:#{isbn}"
      else
        first_author = metadata.creators.first.content
        URI.encode_uri_component(%(intitle:"#{title}" inauthor:"#{first_author}"))
      end
    end
  end

  class Highlight
    extend Forwardable

    REGEX = /
      (\d{4}-\d{2}-\d{2}\s\d{2}:\d{2})  \|  Page\sNo\.:\s(\d+)\n
      (.*?)\n
      (?:【Annotation】(.*?))?
      -------------------
    /xm

    DEFAULT_ATTRIBUTES = {
      source_type: "Boox2Readwise",
    }.freeze

    attr_reader :text, :attributes

    def self.parse(text)
      text.scan(REGEX).map do |highlighted_at, location, highlight_text, note|
        new(
          highlight_text.strip,
          highlighted_at: Time.parse(highlighted_at),
          location: location.to_i,
          note: note&.strip,
        )
      end
    end

    def initialize(text, **attributes)
      @text = text
      @attributes = DEFAULT_ATTRIBUTES.merge(attributes)
    end

    %i[source_type note location location_type highlighted_at].each do |attr|
      define_method(attr) { attributes[attr] }
    end

    def to_readwise
      attributes.merge(highlighted_at: highlighted_at.utc.iso8601, text: text)
    end
  end
end

class TestBoox2Readwise < Minitest::Test
  def setup
    @b2r = Boox2Readwise.new(
      File.expand_path(
        "~/ACCESS/Sources/Books/Pragmatic Bookshelf/Profession/The Pragmatic Programmer, 20th Anniversary Edition/the-pragmatic-programmer-20th-anniversary-edition.p3_0/the-pragmatic-programmer-20th-anniversary-edition.p3_0-annotation-2025-02-09_13_10_39.txt"
      )
    )
  end

  def test_book_metadata
    assert_equal "Dave Thomas, Andy Hunt", @b2r.book.author
    assert_equal "The Pragmatic Programmer", @b2r.book.title
  end

  def test_book_to_readwise
    assert_equal(
      {
        category: "books",
        title: "The Pragmatic Programmer",
        author: "Dave Thomas, Andy Hunt",
        image_url: "http://books.google.com/books/content?id=sNeFxAEACAAJ&printsec=frontcover&img=1&zoom=1&source=gbs_api",
      },
      @b2r.book.to_readwise,
    )
  end

  def test_hightlights_count
    assert_equal 8, @b2r.highlights.size
  end

  def test_timestamp
    assert_equal Time.new(2025, 2, 8, 15, 6), @b2r.highlights[0].highlighted_at
  end

  def test_whitespace_stripping
    assert_equal(
      "The process of becoming a better programmer doesn’t just happen because you know how to code; it must be met with intention and deliberate practice.",
      @b2r.highlights[0].text,
    )
    assert_equal(
      "The word pragmatic comes from the Latin pragmaticus—“skilled in business”—which in turn is derived from the Greek πραγματικός, meaning “fit for use.”",
      @b2r.highlights[1].text,
    )
    assert_equal "Tip 1\nCare About Your Craft", @b2r.highlights[3].text
  end

  def test_multiline_text
    assert_equal "Tip 2\nThink! About Your Work", @b2r.highlights[4].text
  end

  def test_multiline_note
    assert_equal "#tip\nyou can change things at your job for the better", @b2r.highlights[7].note
  end

  def test_highlight_to_readwise
    assert_equal(
      {
        source_type: "Boox2Readwise",
        highlighted_at: "2025-02-08T21:23:00Z",
        location: 32,
        note: "#tip\nyou can change things at your job for the better",
        text: "Tip 3\nYou Have Agency",
      },
      @b2r.highlights[7].to_readwise,
    )
  end

  def test_readwise_payload
    assert_equal(
      {
        category: "books",
        title: "The Pragmatic Programmer",
        author: "Dave Thomas, Andy Hunt",
        image_url: "http://books.google.com/books/content?id=sNeFxAEACAAJ&printsec=frontcover&img=1&zoom=1&source=gbs_api",
        source_type: "Boox2Readwise",
        highlighted_at: "2025-02-08T21:23:00Z",
        location: 32,
        note: "#tip\nyou can change things at your job for the better",
        text: "Tip 3\nYou Have Agency",
      },
      @b2r.readwise_payload[:highlights][7],
    )
  end
end

if ARGV.size > 1
  warn "Usage: #{$PROGRAM_NAME} <test|dir|annotation_file.txt>"
  exit 1
end

arg = ARGV.first

if arg == "test"
  Minitest.run %w[--no-plugins]
elsif File.directory?(arg)
  Dir["**/*.txt", base: arg].each do |file|
    begin
      b2r = Boox2Readwise.new(File.join(arg, file))
      puts "Processing #{file}"
      b2r.push_to_readwise
      b2r.clean
    rescue Boox2Readwise::Book::ParseError => e
      warn "Skipping #{file}: #{e.message}"
    end
  end
elsif File.file?(arg)
  b2r = Boox2Readwise.new(arg)
  b2r.push_to_readwise
  b2r.clean
else
  fail "Can't find file or directory: #{arg}"
end
