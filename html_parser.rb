#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

ident = regexp(/[A-Za-z][A-Za-z0-9_:.]*/)
dollar_expression = sequence(string("${"), ident, string("}"))

p dollar_expression.parse("${obj.property}")
