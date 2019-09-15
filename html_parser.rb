#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

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
    seq(ident, space.many,
         string("="), space.many,
         (quoted_string | unquoted_value)
        ) | ident
  end

  # tag :: "<" ident (attribute)* ">"
  #       | "<" ident (attribute)* "/>"
  #       | "</" ident ">"
  def tag
    seq(string("<"), space.many,
         ident, space.many,
         seq(attribute, space.many).many,
         string(">")) |
    seq(string("<"), space.many,
         ident, space.many,
         seq(attribute, space.many).many,
         string("/>")) |
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
         string("<!DOCTYPE html>"),
         (tag | text | space).many,
        ) << eof
  end
end

if $0 == __FILE__
  ARGV.each {|file|
    buf = File.binread(file)
    buf = HtmlParser.new.html.parse(buf).join
    File.rename(file, file + ".bak")
    File.open(file, "wb") {|o| o.print buf}
  }
end
