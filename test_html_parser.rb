#!/usr/bin/ruby
# coding: utf-8

require 'minitest/autorun'
require_relative 'html_parser.rb'

module RParsec::Parsers
  def parse_to_eof(input)
    (self << eof).parse(input)
  end
end

class HtmlParserTest < Minitest::Test
  def setup
    @parser = HtmlParser.new
  end

  def test_ident
    assert_equal "abc", @parser.ident.parse_to_eof("abc")
    assert_equal "obj.property", @parser.ident.parse_to_eof("obj.property")
    e = assert_raises RParsec::ParserException do
      @parser.ident.parse_to_eof("${obj.property}")
    end
    assert_equal "/(?-mix:[A-Za-z][A-Za-z0-9_:.]*)/ expected, $ at line 1, col 1.", e.message
  end

  def test_dollar_expression
    assert_equal "${obj.property}",
                 @parser.dollar_expression.parse_to_eof("${obj.property}").join
  end

  def test_quoted_string
    str = '"abc"'
    assert_equal(str, @parser.quoted_string.parse_to_eof(str))
    str = "'abc'"
    assert_equal(str, @parser.quoted_string.parse_to_eof(str))
    str = %q('a"bc')
    assert_equal(str, @parser.quoted_string.parse_to_eof(str))
    str = %q("a'bc")
    assert_equal(str, @parser.quoted_string.parse_to_eof(str))
  end

  def test_attribute
    str = 'foo="bar"'
    assert_equal(str, @parser.attribute.parse_to_eof(str).to_s)
    str = "foo='bar'"
    assert_equal(str, @parser.attribute.parse_to_eof(str).to_s)
    str = "foo = 'bar'"
    assert_equal(str, @parser.attribute.parse_to_eof(str).to_s)
    str = "foo"
    assert_equal(str, @parser.attribute.parse_to_eof(str))
    str = "foo=bar"
    assert_equal(str, @parser.attribute.parse_to_eof(str).to_s)
  end

  def test_attribute_thtext
    str = 'th:text="${obj.property}"'
    attribute = @parser.attribute.parse(str)
    assert_equal('th:text', attribute.name)
    assert_equal('"${obj.property}"', attribute.value)
    assert_equal('${obj.property}', attribute.unquoted_value)
  end

  def test_html
    html = <<END
<!--
テスト
-->
<!DOCTYPE HTML>

<head>
</head>

<body>
  <div foo="bar">
  </div>
  <div th:text="${obj.property}">
  </div>
</body>
END
    expected = html.sub('<div th:text="${obj.property}">',
                        '<div th:text="${obj.property}" data-prop=\'property\'>',
                       )

    ret = @parser.html.parse_to_eof(html.force_encoding('ASCII-8BIT'))
    assert_equal expected.force_encoding('ASCII-8BIT'), HtmlParser.walk(ret)
  end
end
