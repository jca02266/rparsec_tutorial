#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

class Function
  def initialize(repr, name, *params)
    @repr = repr
    @name = name
    @params = params
  end

  def property
    case @name
    when 'xxx.function1' then @params[0].property
    when 'xxx.function2' then @params[1].property
    else
      raise RuntimeError.new("unknown function #{@name}")
    end
  end

  def to_s
    @repr
  end
end

class Params
  def initialize(repr, *params)
    @repr = repr
    @params = params
  end

  def to_s
    @repr
  end

  def params
    @params
  end
end

class Ident
  def initialize(repr)
    @repr = @ident = repr
  end

  def property
    if /\.([^.]+)\z/ =~ @ident
      $1
    end
  end

  def to_s
    @repr
  end
end

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
    lazy {
      seq(expression, space.many, string(","), space.many, params)
    }.map {|e|
      exp, _, _, _, para = e
      Params.new(e.join, exp, *para.params)
    } |
    expression.map {|v| Params.new([*v].join, v) }
  end

  def function
    sequence(string("#"), ident, string("("), params.optional(Params.new('')), string(")")) {|*e|
      _, id, _, para, _ = e
      Function.new(e.join, id, *para.params)
    }
  end

  def term
    lazy { ident.map {|e| Ident.new(e)} |
           literal |
           function
         }
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

  def self.walk(parsed_object, property)
    case parsed_object
    when Array
      parsed_object.map {|s|
        self.walk(s, property)
      }.join
    when Ident, Function
      property.push parsed_object.property
      parsed_object.to_s
    else
      parsed_object.to_s
    end
  end
end
