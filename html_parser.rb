#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'
require_relative 'spel_parser.rb'

include RParsec::Parsers

class Attribute
  def initialize(repr, name, value)
    @repr = repr
    @name = name
    @value = value
  end

  attr_reader :name, :value

  def to_s
    @repr
  end

  def unquoted_value
    @value.sub(/"(.*?)" | '(.*?)' | (.*?)/x) { $+ }
  end
end

class Tag
  def initialize(repr, tag, attributes)
    @repr = repr
    @tag = tag
    @attributes = attributes
  end

  attr_reader :tag, :attributes

  def to_s
    th_text_attribs = @attributes.flat_map {|v| v}.select {|a|
      Attribute === a && a.name == 'th:text'
    }

    if th_text_attribs.size > 1
      # th:text が複数あるタグは元のHTMLのエラーとみなす
      raise RuntimeError.new("Syntax Error: #@repr")
    end

    if th_text_attribs.empty?
      @repr
    else
      # th_text_attribs[0].unquoted_value をパースしてpropertyを抽出する
      ret = SpelParser.new.parse(th_text_attribs[0].unquoted_value)
      properties = []
      SpelParser.walk(ret, properties)
      case properties.size
      when 1
        @repr.sub(/>/, " data-prop='#{properties[0]}'>")
      when 0
        @repr
      else
        raise RuntimeError.new("Too many properties: #{properties.inspect}")
      end
    end
  end
end

class HtmlParser
  def seq(*args)
    sequence(*args) {|*e|
      e
    }
  end

  def ident
    regexp(/[A-Za-z][A-Za-z0-9_:.]*/)
  end

  def dollar_expression
    seq(string("${"), ident, string("}"))
  end

  # quoted_string :: "'" any* "'"
  #                | '"' any* '"'
  def quoted_string
    regexp(/' .*? '/x) |
    regexp(/" .*? "/x)
  end

  # unquoted_value :: [^"' \t\f\r\n=<>`/]+
  def unquoted_value
    regexp(%r{[^"' \t\f\r\n=<>`/]+})
  end

  # attribute :: ident "=" quoted_value
  #            | ident "=" unquoted_value
  #            | ident
  def attribute
    sequence(ident, space.many,
         string("="), space.many,
         (quoted_string | unquoted_value)
        ) {|*e|
      Attribute.new(e.join, e[0], e[4])
    } |
    ident
  end

  # tag :: "<" ident (attribute)* ">"
  #       | "<" ident (attribute)* "/>"
  #       | "</" ident ">"
  def tag
    tag_proc = Proc.new {|*e|
      Tag.new(e.join, e[2], e[4])
    }

    sequence(string("<"), space.many,
         ident, space.many,
         seq(attribute, space.many).many,
         string(">"), &tag_proc) |
    sequence(string("<"), space.many,
         ident, space.many,
         seq(attribute, space.many).many,
         string("/>"), &tag_proc) |
    seq(string("</"), space.many,
         ident, space.many,
         string(">"))
  end

  def text
    any
  end

  def space
    regexp(/[ \t\f\r\n]+/) | comment_block
  end

  def comment_block
    seq(string("<!--"), not_string("-->").many, string("-->"))
  end

  def html
    seq(space.many,
         string_nocase("<!DOCTYPE html>"),
         (tag | text | space).many,
        ) << eof
  end

  def self.walk(parsed_object)
    case parsed_object
    when Array
      parsed_object.map {|s|
        self.walk(s)
      }.join
    else
      parsed_object.to_s
    end
  end
end

if $0 == __FILE__
  ARGV.each {|file|
    buf = File.binread(file)
    ret = HtmlParser.new.html.parse(buf)
    buf = HtmlParser.walk(ret)
    File.rename(file, file + ".bak")
    File.open(file, "wb") {|o| o.print buf}
  }
end
