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

  def html
    seq(string("<!DOCTYPE html>"),
        (tag | text).many,
        ) << eof
  end
end
