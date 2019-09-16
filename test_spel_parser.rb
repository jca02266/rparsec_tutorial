#!/usr/bin/ruby
# coding: utf-8

require 'minitest/autorun'
require_relative 'spel_parser.rb'

module RParsec::Parsers
  def parse_to_eof(input)
    (self << eof).parse(input)
  end
end

class SpelParserTest < Minitest::Test
  def setup
    @parser = SpelParser.new
  end

  def test_op
    assert_equal "+", @parser.op.parse_to_eof("+")
    assert_equal "-", @parser.op.parse_to_eof("-")
  end

  def test_number
    assert_equal "012", @parser.number.parse_to_eof("012")
  end

  def test_quoted_value
    assert_equal '"abc"', @parser.quoted_value.parse_to_eof('"abc"')
  end

  def test_literal
    assert_equal '012', @parser.literal.parse_to_eof('012')
    assert_equal '"abc"', @parser.literal.parse_to_eof('"abc"')
  end

  def test_ident
    assert_equal 'abc', @parser.ident.parse_to_eof('abc')
    assert_equal 'abc.def', @parser.ident.parse_to_eof('abc.def')
  end

  def test_params
    assert_equal '012', @parser.params.parse_to_eof('012')
    assert_equal '012, "abc"', @parser.params.parse_to_eof('012, "abc"').join
  end

  def test_function
    assert_equal '#xxx.function1()', @parser.function.parse_to_eof('#xxx.function1()').join
    assert_equal '#xxx.function1(012)', @parser.function.parse_to_eof('#xxx.function1(012)').join
    assert_equal '#xxx.function1(012, "abc")', @parser.function.parse_to_eof('#xxx.function1(012, "abc")').join
    assert_equal '#xxx.function1(012, "abc", #func())', @parser.function.parse_to_eof('#xxx.function1(012, "abc", #func())').join
  end

  def test_term
    assert_equal 'abc.def', @parser.term.parse_to_eof('abc.def')
    assert_equal '012', @parser.term.parse_to_eof('012')
    assert_equal '"abc"', @parser.term.parse_to_eof('"abc"')
    assert_equal '#xxx.function(012, "abc")', @parser.term.parse_to_eof('#xxx.function(012, "abc")').join
  end

  def test_expression
    assert_equal 'abc.def', @parser.expression.parse_to_eof('abc.def')
    assert_equal 'abc.def + 012', @parser.expression.parse_to_eof('abc.def + 012').join
    assert_equal '#function(abc.def + 012)', @parser.expression.parse_to_eof('#function(abc.def + 012)').join
  end

  def test_dollar_expression
    assert_equal '${#function(abc.def + 012) + "012"}', @parser.dollar_expression.parse_to_eof('${#function(abc.def + 012) + "012"}').join
  end
end
