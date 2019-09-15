#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

ident = regexp(/[A-Za-z][A-Za-z0-9_:.]*/)

p ident.parse("abc")
p ident.parse("obj.property")
p ident.parse("${obj.property}")
