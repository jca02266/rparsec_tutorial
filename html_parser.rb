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

  def tag
    any
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
