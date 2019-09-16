#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

class SpelParser
  def seq(*args)
    sequence(*args) {|*e|
      e
    }
  end

  def space
    regexp(/[ \t\f\r\n]+/)
  end

  def op
    string("+") | string("-")
  end

  def number
    regexp(/[0-9]+/)
  end

  def quoted_value
    regexp(/" .*? "/x)
  end

  def literal
    quoted_value | number
  end

  def ident
    regexp(/[A-Za-z][A-Za-z0-9.]*/)
  end

  def params
    lazy { seq(expression, space.many, string(","), space.many, params) } |
    expression
  end

  def function
    seq(string("#"), ident, string("("), params.optional, string(")"))
  end

  def term
    lazy { ident | literal | function }
  end

  def expression
    lazy { seq(term, space.many, op, space.many, expression) } |
    term
  end

  def dollar_expression
    seq(string("${"), expression, string("}"))
  end

  def parse(s)
    (dollar_expression << eof).parse(s)
  end
end
