#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

def seq(*args)
  sequence(*args) {|*e|
    e
  }
end

ident = regexp(/[A-Za-z][A-Za-z0-9_:.]*/)
dollar_expression = seq(string("${"), ident, string("}"))

p (dollar_expression << eof).parse("${obj.property}")
