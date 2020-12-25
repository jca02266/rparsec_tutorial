# 動機

正規表現よりもパーサが適していると思った時には迷わずパーサを使えるようになりたい。

# 課題例

複数人でプログラムを作っていると書き方の揺れとかたくさん出てくる。
この揺れを解決するためのスクリプトを作ることはよくあることだ。

例えば、私はrubyistなので以下のようなスクリプトによる一括置換をよくやる。
これは意味のない例だが、ソース上の `"abc" + "def"` を `"abcdef"` に置換する
スクリプトになっている。

```ruby:replace.rb
#!/usr/bin/ruby
# coding: utf-8

# "abc" + "def" を "abcdef" にする

regexp = /("abc") \+ ("def")/
replace = '"#$1#$2"'

ARGV.each {|file|
  buf = File.read(file)
  buf = buf.gsub(regexp, replace)
  File.open(file, "w") {|o| o.print buf}
}
```

```ruby:a.rb
"abc" + "def"
```

```console
$ ruby replace.rb a.rb
$ cat a.rb
"abcdef"
```

# 正規表現の問題点

先ほどの正規表現による一括置換スクリプトを必要に応じて書き換えて使っている。
しかし、問題点も存在する。

* 正規表現のメタ文字を意識しなければならないため、複雑なパターンを正規表現にするのは大変
* 複数行に別れたパターンも考慮すると正規表現が複雑になる。インデントのサイズも保存して置換するなど処理自体も煩雑になる。
  (そもそもエディタの置換機能を使わないのはこのような複数行にまたがるパターンに対応するためである)
* プログラムの文法を考慮できない。コメントや文字列内の文字も置換してしまう
  (コメントも置換したい場合もあるが)

そこで、プログラムを書き換えるというこの課題をパーサで解決する方法を試行錯誤しようと思う。

# 利用するツール、ライブラリ

パーサはその手軽さからパーサコンビネータを使うとして言語やライブラリをどうすべきかだが、

* 言語: ruby (ruby 2.6.4p104)
* ライブラリ: RParsec

を使うこととした。Haskellやpython+[parsec.py](https://github.com/sighingnow/parsec.py)というのも考えたが、
慣れたrubyを使うことで問題解決に注力したいというのが理由である。

不安な点としてはRParsecは長いことメンテナンスされていないという点がある。
とりあえず、RParsec のリポジトリをフォークしてruby2.6で動くようにはしておいた。

* [rparsecのruby2ブランチ](https://github.com/jca02266/rparsec/tree/ruby2)

# 改めて課題例

練習のための課題としてHTMLをパースして、ある特定の条件に一致するタグに属性を追加したい。

これは、実際に私が直面した課題である。

HTMLくらいは専用のツールを使うなども考えられるが、今回、[Thymeleaf](https://www.thymeleaf.org/doc/tutorials/3.0/usingthymeleaf.html) の式も解釈したいというのもあり、パーサを使うこととした。問題を具体的に示そう。

```html
<div th:text='${obj.property}'> ... </div>
```

を

```html
<div th:text='${obj.property}' data-prop='property'> ... </div>
```

のように変えたい。また、`${}` の部分には以下のようなパターンがある

```
${obj.property}
${obj.property + "abc"}
${#xxx.function1(obj.property)}
${#xxx.function2("abc", obj.property)}
```

これらからプロパティ `property` に該当する文字列を取得し、data-prop='property' を追加するというのが実現したいことである。

この目的はわからないと思うが、問題に対してパーサによる解決手段が妥当であることはわかるだろう。
実際に直面した問題では、他にもパターンはあるのだがこの記事の説明としてはこの程度で十分だろう。

# RParsecチュートリアル

まずHTML全体をパースするプログラムを作ってみよう。HTMLはパーサで解釈するには単純なので導入としてちょうど良いと思う。
と言いながらもRParsecの基本やハマりどころ(ハマったところ)などを解説しながら説明するのでこのチュートリアルはかなり長い。コードを確認しながら読む覚悟をすること。

## STEP1: regexpパーサ

最初にRParsecを取ってくるところから始める。RParsec は私がruby2.4向けに修正したものを使う。

```console
$ mkdir html_parser
$ cd html_parser
$ git clone https://github.com/jca02266/rparsec.git
$ (cd rparsec && git checkout ruby2)
```

そして、以下のようなサンプルを作る

```ruby:html_parser.rb
#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

ident = regexp(/[A-Za-z][A-Za-z0-9_:.]*/)

p ident.parse("abc")
p ident.parse("obj.property")
p ident.parse("${obj.property}")
```

以下が実行例である。エラーになるがわざとなのでびっくりしないで欲しい。

```console
$ ruby html_parser
"abc"
"obj.property"
.../html_parser/rparsec/rparsec/parser.rb:70:in `parse': /[A-Za-z][A-Za-z0-9_.]*/ expected, $ at line 1, col 1. (RParsec::ParserException)
	from html_parser.rb:12:in `<main>'
```

作成した `ident` は識別子をパースするパーサである。

> RParsec解説
> `Parsers.regexp()`
> は、指定された正規表現に従って文字列をパースするパーサである。

スクリプト中、`RParsec::Parsers`をincludeしているので `RParsec::Parsers` を省略して書けるが、説明文中では Parsers を明記することとする

最初の2つの例では abc や obj.property のような識別子をパースした。RParsecのパーサはパースに成功するとパースした文字列を返すようになっている。

3番目の例ではパースに失敗した例を示した。`$`のような文字は識別子ではないので、パーサは例外ParserExceptionを起こす。そして、`... expected, $ at line 1, col 1.` でパースに失敗した文字と位置を表示している。


ソース: [1st step](https://github.com/jca02266/rparsec_tutorial/blob/step1/html_parser.rb)

## STEP2: string, sequence パーサ

もう少し、拡張してみよう。上記を以下のように書き換える。

```ruby:html_parser.rb
#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './rparsec'
require 'rparsec.rb'

include RParsec::Parsers

ident = regexp(/[A-Za-z][A-Za-z0-9_:.]*/)
dollar_expression = sequence(string("${"), ident, string("}")) # <-- 追加

p dollar_expression.parse("${obj.property}")
```

```console
$ ruby html_parser.rb
"}"
```

> RParsec 解説
> `Parsers.string()`
> は、指定した固定の文字列をパースするパーサでこの例では `${` および `}` をパースする
>
> `Parsers.sequence()`
> は指定したパーサの並びをパースするパーサで、パーサの連結を表す。

作成した `dollar_expression` というパーサは、`"${"`, `"obj.property"`, `"}"` というパースを順に行うパーサとなっている。

ソース: [2nd step](https://github.com/jca02266/rparsec_tutorial/blob/step2/html_parser.rb)

## STEP3: sequence パーサ(ブロック付き)

ここで、2点ほどこのパーサの問題点を示す。

まず、1点目、`Parsers.sequence()` は、最後の引数で指定したパーサの結果である `"}"` を返している。

この最後の結果を返すという動きは今回の目的には即していないので以下のようなメソッドを用意する。

```ruby
def seq(*args)
  sequence(*args) {|*e|
    e
  }
end
```

> RParsec 解説
>
> `Parsers.sequence() {|*results| ...}`
> はブロックを指定すると、引数に指定した各パーサの結果を引数にブロックを呼び出し、その結果を返す。

これを利用してパーサの結果すべてを配列にして返すパーサ `seq` を定義した。使ってみよう。

```ruby
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

p dollar_expression.parse("${obj.property}")
```

```console
$ ruby html_parser.rb
["${", "obj.property", "}"]
```

seq()は配列(引数で渡した各パーサの結果の配列)を返すパーサとなったので、これでうまく動いている。

ソース: [3rd step](https://github.com/jca02266/rparsec_tutorial/blob/step3/html_parser.rb)

## STEP4: eofパーサ, `<<`パーサ

問題の2点目だが、このパーサは入力に余分な文字列を与えても動く。つまり、文字列の末尾を以下のように変えても正常に動作する。

```ruby
p dollar_expression.parse("${obj.property} foo bar baz")
```

```console
$ ruby html_parser.rb
["${", "obj.property", "}"]
```

これはパーサとしては不完全である。これを解決するには、`Parsers.eof()` パーサを使う。

> RParsec解説
> `Parsers.eof()`
> eofをパースするパーサ。直前のパーサの結果を返す。

eof の使い方の注意として、eof は直前のパーサの結果を返すようになっている。
そのため、

```ruby
p seq(dollar_expression, eof).parse("${obj.property}")
```

この結果は以下のように結果が二重に出力される。

```console
$ ruby html_parser.rb
[["${", "obj.property", "}"], ["${", "obj.property", "}"]]
```

このため、eof は以下のような使い方をする。

```ruby
p (dollar_expression << eof).parse("${obj.property}")
```

> RParsec解説
> `Parsers#<<`
> は右辺のパーサの評価を行うがその結果を捨てるパーサである。

ここでは理解しなくとも、`<< eof` という使い方をするものだと覚えておこう。

ソース: [4th step](https://github.com/jca02266/rparsec_tutorial/blob/step4/html_parser.rb)

## STEP5: パーサのテスト

さて、この調子でどんどんパーサを追加していっても良いのだが
動作確認のためにいちいちプログラムをいじるのは大変なのでテストを追加しよう。

html_parser.rb を以下のように書き換える

```ruby:html_parser.rb
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
end
```

ソース: [5th step](https://github.com/jca02266/rparsec_tutorial/blob/step5/html_parser.rb)

そして、以下のテストを作成する。

```ruby:test_html_parser.rb
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
end
```

テスト: [5th step](https://github.com/jca02266/rparsec_tutorial/blob/step5/test_html_parser.rb)

実行してみる。以下のように成功するはずだ。

```console
$ ruby test_html_parser.rb
Run options: --seed 36088

# Running:

..

Finished in 0.001377s, 1452.4328 runs/s, 3631.0820 assertions/s.

2 runs, 5 assertions, 0 failures, 0 errors, 0 skips
```

これまではパーサ定義をローカル変数に代入して使用していたが、パーサが多くなってくるとスコープの限界が来る。ちゃんと作る場合はこの例のようにメソッドとして定義した方が良い。

これまで定義したパーサは文字列を返していたが、最後に定義した
`dollar_expression` パーサは配列を返しているので、テストではその結果をjoinして文字列で評価している。
`dollar_expression` が直接文字列を返さない点は後々重要になってくる。

以降、HtmlParserとテストにメソッドを追加しながら課題を解いていこう。

ソース全体: [5th step](https://github.com/jca02266/rparsec_tutorial/tree/step5/)

## HTMLのBNF([バッカス・ナウア記法](https://ja.wikipedia.org/wiki/%E3%83%90%E3%83%83%E3%82%AB%E3%82%B9%E3%83%BB%E3%83%8A%E3%82%A6%E3%82%A2%E8%A8%98%E6%B3%95))

これから作成するパーサの全体像を定義してみよう。

以下のBNF(っぽいもの)で定義してみた。この定義はHTMLとして正確な定義ではない(正確な定義は確認していない)が、自分の問題領域の解決には十分である。この時点であらゆるHTMLに対応しようなどと考えない姿勢は重要だと思う。

```
html :: "<!DOCTYPE html>" (tag | text)+ eof
tag :: "<" ident (attribute)* ">"
      | "<" ident (attribute)* "/>"
      | "</" ident ">"
attribute :: ident "=" quoted_value
           | ident "=" unquoted_value
           | ident
quoted_value :: "'" any* "'"
              | '"' any* '"'
ident = /[A-Za-z][A-Za-z0-9_.:]*/
space = /[ \f\t\r\n]+/ | comment_block
comment_block = "<!--" any* "-->"
text :: any+
```

tag の定義に関しては

```
tag :: "<tag>" (tag | text) </tag>
```

のようにタグと閉じタグの関係と入れ子(tag の定義にtagを利用している)を表現した方が良いかもしれないが、今回そこまで厳密にする必要がなかったのでそれはしていない。
最初の`"<tag>"`にマッチした `tag` を使って、`"</tag>"` をパースするやり方がわからなかったのもある。

## STEP6: `|`(選択), `many`, `any`

html の定義は以下のようになる

```ruby
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
```

> RParsec解説
> `Parsers#|`
> `tag | text` の `|` は選択を表し、いずれかのパーサにマッチするパーサである。演算子形式だがパーサであることに注意
>
> `Parsers#many`
> many もパーサでレシーバが0回以上繰り返すことを表す。
>
> 正規表現で言えば
>
> ```
> (pattern | pattern) : |
> (pattern)* : many
> ```
>
> に対応する
>
> `Parsers.any`
> は何にでもマッチするパーサである。とりあえず、`tag`や`text`の定義を後回しにしたかったので利用した。
> 入力を全て食ってしまうので今回のような残り全部といった使い方しか出来ないと思われる。

そして、テストは以下になる

```ruby
  def test_html
    html = "<DOCTYPE html><head></head><body></body>"
    assert_equal html,
                 @parser.html.parse_to_eof(html)
  end
```

やってみよう

ソース全体: [6th step](https://github.com/jca02266/rparsec_tutorial/tree/step6/)

```console
$ ruby test_html_parser.rb
...
  1) Error:
HtmlParserTest#test_html:
RParsec::ParserException: "<!DOCTYPE html>" expected, < at line 1, col 1.
    ...html_parser/rparsec/rparsec/parser.rb:70:in `parse'
    test_html_parser.rb:9:in `parse_to_eof'
    test_html_parser.rb:35:in `test_html'

3 runs, 5 assertions, 0 failures, 1 errors, 0 skips
```

エラーになった。以下の部分がパーサのエラーメッセージだ。

```
RParsec::ParserException: "<!DOCTYPE html>" expected, < at line 1, col 1.
```

これは本当に間違えてしまったのだが、テストコードで `"<!DOCTYPE..."` と書かなければいけないところを `"<DOCTYPE..."` と `!`を忘れて書いてしまった。
RParsecのエラーメッセージはエラー位置を `line 1, col 1` と表示している(col 2としてくれなかった)点に注意する必要がある。(この為すぐに原因に気づかなかった)

気を取り直して、テストコードを修正しよう

```ruby
  def test_html
    html = "<!DOCTYPE html><head></head><body></body>"
    assert_equal html,
                 @parser.html.parse_to_eof(html).join
  end
```

これでうまくいく。

ソース全体: [6th-fix step](https://github.com/jca02266/rparsec_tutorial/tree/step6-fix/)

## STEP7: 空白、コメントのパーサ (not_string)

先ほど定義した html は空白を含めることができないのでそこを改善しよう。

```ruby
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
```

空白の定義を
`空白類の文字列 | ブロックコメント`
と、空白類の文字列だけでなく、コメントも含めるのはプログラミング言語でよくあることだが、HTMLに対してはこれはやり過ぎだったようだ。

つまり、C言語やJava言語で

```
  int/* comment */foo;
```

と出来てもHTMLでは

```
  <div<!-- comment -->attrib=value>
```

とは出来ないのでこのパーサは間違いである。まあ良しとする。

> RParsec解説
> `Parsers.not_string()`
> は、引数で指定した文字列以外の文字列にマッチするパーサである。
>
> 似非BNFで以下のように表したコメントブロックは
>
> ```
> comment_block = "<!--" any* "-->"
> ```
>
> 実際に any とすると "-->" の部分まで any が消費してしまうためうまくいかない。
> このような場合に `not_string` を利用して「終端記号以外の文字列」の並びを表す。

test_html を書き換えよう

```ruby
  def test_html
    html = <<END
<!--
テスト
-->
<!DOCTYPE html>

<head>
</head>

<body>
</body>
END
    assert_equal html,
                 @parser.html.parse_to_eof(html.force_encoding('ASCII-8BIT')).join
  end
```

> RParsec解説
> 今まで触れなかったが、RParsecは入力を文字単位ではなくバイト単位でパースする。
> これは、RParsec が内部で利用している StringScanner の仕様による。
> したがって、rparsec の入力は常にバイナリ文字列でなければならないことに注意が必要である。
> 上記では、パース対象に日本語を含めると同時に、html.force_encoding('ASCII-8BIT')
> とすることでバイナリ文字列を入力にしている。
> 誤ってforce_encoding('ASCII-8BIT')を指定せずにマルチバイト文字を含むテキストをそのまま入力にすると
>
> ```
> RParsec::ParserException: "<!DOCTYPE html>" expected,
>  at line 3, col 4.
> ```
>
> と原因不明のエラーになってしまう。

ソース全体: [7th step](https://github.com/jca02266/rparsec_tutorial/tree/step7/)

## STEP8: tag, attribute

一気にやってしまおう

```ruby
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
```

quoted_string は改行を含まない文字列として単純に定義している
(おそらくはHTMLの仕様としてもこれで十分だろう)

```ruby
  def quoted_string
    regexp(/' .*? '/x) |
    regexp(/" .*? "/x)
  end
```

文字列リテラルは例えばC言語の文字列(backslash('\')によりクォートをエスケープできる)を表現する場合もある。この正規表現は使えるのでメモとして残しておく。
(文字列中の改行も[^\\"]により許していることに注意)

```ruby
    regexp(/" (?: \\. | [^\\"]+ )* "/x)
```

attribute や tag については特に新しいことはない。
テストも特筆するべき箇所はないので特に解説はしない。

```ruby

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
    assert_equal(str, @parser.attribute.parse_to_eof(str).join)
    str = "foo='bar'"
    assert_equal(str, @parser.attribute.parse_to_eof(str).join)
    str = "foo = 'bar'"
    assert_equal(str, @parser.attribute.parse_to_eof(str).join)
    str = "foo"
    assert_equal(str, @parser.attribute.parse_to_eof(str))
    str = "foo=bar"
    assert_equal(str, @parser.attribute.parse_to_eof(str).join)
  end
```

ソース全体: [8th step](https://github.com/jca02266/rparsec_tutorial/tree/step8/)

## STEP9: main

今回の処理の目的としてメイン処理は引数に与えられたファイルを読み、ファイルの内容を置き換える処理とする。

ruby の常套句として以下のように記述する。

```ruby
if $0 == __FILE__
  ARGV.each {|file|
    buf = File.binread(file)
    buf = HtmlParser.new.html.parse(buf).join
    File.rename(file, file + ".bak")
    File.open(file, "wb") {|o| o.print buf}
  }
end
```

実行すると引数に指定したhtmlファイルをhtml.bakにリネームしてパーサが読み込んだhtmlを(今はまだ無加工で)出力する。

前にも書いたがRParsecの制約から入力(`File.binread`)も出力(`File.open(..., "wb")`)もバイナリとしている点に注意すること。

```html:sample.html
<!--
テスト
-->
<!DOCTYPE html>

<head>
</head>

<body>
</body>
```

```console
$ ruby html_parser.rb sample.html
$ diff sample.html{.bak,}
```

新しく生成されたhtmlとバックアップファイルとの差分がなければここではOKである。

ソース全体: [9th step](https://github.com/jca02266/rparsec_tutorial/tree/step9/)

## STEP10: 出力を加工する(準備)

さて、本来の目的であるプログラムの加工処理について考える。
パーサに処理を挟む場所としては、sequence メソッドのブロックがある。

```
sequence() {...}
```

文字列の代わりに配列を返すように seq() メソッドを定義した箇所でも利用例を示した。
これを利用してパーサの戻り値に情報を詰めたオブジェクトを返すようにしよう。

まず、attribute (foo="bar") を表現する以下のクラスを作成する。

```ruby
class Attribute
  def initialize(repr, name, value)
    @repr = repr
    @name = name
    @value = value
  end

  attr_reader :name, :value

  def to_s
    @repr
  end
end
```

`initialize` の第一引数は元のソース文字列となっている。このクラスは後で name, value の値を取り出すために使うもので、出力自体は元のソースを再現できなければならないので、このようになっている。

そして、attribute のパーサを書き換えて、Attribute のインスタンスを返すパーサに変更する。

```ruby
  def attribute
    sequence(ident, space.many,
         string("="), space.many,
         (quoted_string | unquoted_value)
        ) {|*e|
      Attribute.new(e.join, e[0], e[4])
    } |
    ident
  end
```

`=` 記号のない属性については元の文字列のままとしている(`ident` のみの行の部分)が、
value がない Attribute オブジェクトとしてももちろん構わない

テストは、以下のように `join` を `to_s` に書き換えなければならない。

```ruby
  def test_attribute
    str = 'foo="bar"'
    assert_equal(str, @parser.attribute.parse_to_eof(str).to_s)

    # ... 略
  end
```

test_html に影響がないことに注意。rubyのArray#join は要素に対して再帰的に to_s を呼び出すため、これでうまく動作する。
しかし、これはわかりにくい動作であるため、パースした結果を処理する箇所を明示的にしよう。

以下のように HtmlParser.walk() を定義し、パーサの戻り値をこのメソッドに渡すことで
加工した文字列を返す仕様とする。

```ruby:html_parser.rb
class HtmlParser
  # ...

  def self.walk(parsed_object)
    case parsed_object
    when Array
      parsed_object.map {|s|
        self.walk(s)
      }.join
    else
      parsed_object.to_s
    end
  end
end

if $0 == __FILE__
  ARGV.each {|file|
    buf = File.binread(file)
    ret = HtmlParser.new.html.parse(buf)
    buf = HtmlParser.walk(ret)
    File.rename(file, file + ".bak")
    File.open(file, "wb") {|o| o.print buf}
  }
end
```

この`HtmlParser.walk()`は、`Array#join`とやってることはそんなに変わらない。

```ruby:test_html_parser.rb
  def test_html
    html = <<END
<!--
テスト
-->
<!DOCTYPE html>

<head>
</head>

<body>
</body>
END
    ret = @parser.html.parse_to_eof(html.force_encoding('ASCII-8BIT'))
    assert_equal html, HtmlParser.walk(ret)
  end
```

ソース全体: [10th step](https://github.com/jca02266/rparsec_tutorial/tree/step10/)

> RParsec解説
> この例のように本処理はトップのパーサ(ここではhtml)が返した結果に対して処理するという形を取らなければならないことに注意すること。
>
> 例えば attribute パーサの中で副作用のある出力(ソースの書き換えなど)を行ってはならない(今回の例なら上手くいくかもしれないが、少なくとも破壊的な操作は禁止である)。
> パーサの動作は、例えばある attribute で成功したとしても、上位のパーサでやはり失敗となり結果が捨てられる可能性がある。従って、最上位のパーサの結果を使って最後に上手くいった結果だけを利用する必要がある。

## STEP11: 出力を加工する(準備2)

次に Attribute オブジェクトを使ってタグを書き換える Tag クラスを準備する。

```
class Tag
  def initialize(repr, tag, attributes)
    @repr = repr
    @tag = tag
    @attributes = attributes
  end

  attr_reader :tag, :attributes

  def to_s
    @repr
  end
end
```

これも一旦は値を保持するだけの実装にする。tag パーサは以下のようになる。

```ruby
  def tag
    tag_proc = Proc.new {|*e|
      Tag.new(e.join, e[2], e[4])
    }

    sequence(string("<"), space.many,
         ident, space.many,
         seq(attribute, space.many).many,
         string(">"), &tag_proc) |
    sequence(string("<"), space.many,
         ident, space.many,
         seq(attribute, space.many).many,
         string("/>"), &tag_proc) |
    seq(string("</"), space.many,
         ident, space.many,
         string(">"))
  end
```

2つのパターンに同じブロックを渡した方が見通しが良いので、`tag_proc` を作って `sequence()` の最後の引数に &tag_proc でブロックを渡すようにした。閉じタグは元の処理と同様に、文字列のままとしている。

これも元の処理に影響がないことをテストで確認しよう。

```console
$ > ruby test_html_parser.rb
Run options: --seed 3647

# Running:

.....

Finished in 0.004098s, 1220.1074 runs/s, 3660.3221 assertions/s.

5 runs, 15 assertions, 0 failures, 0 errors, 0 skips
```

ソース全体: [11th step](https://github.com/jca02266/rparsec_tutorial/tree/step11/)

## STEP12: 出力を加工する

さて、実際に元の文字列を書き換える処理を追加する。まず、以下のテストを追加する。

```ruby
  def test_attribute_thtext
    str = 'th:text="${obj.property}"'
    attribute = @parser.attribute.parse(str)
    assert_equal('th:text', attribute.name)
    assert_equal('"${obj.property}"', attribute.value)
    assert_equal('${obj.property}', attribute.unquoted_value)
  end
```

Attribute クラスには以下のメソッドを追加する

```ruby
class Attribute
  # ...
  def unquoted_value
    @value.sub(/"(.*?)" | '(.*?)' | (.*?)/x) { $+ }
  end
end
```

そして、TagクラスでAttribute#name が "th:text" だった場合は、この値を(まずは) そのまま追加する処理に変更する。

```ruby
class Tag
  ..
  def to_s
    th_text_attribs = @attributes.flat_map {|v| v}.select {|a|
      Attribute === a && a.name == 'th:text'
    }

    if th_text_attribs.size > 1
      # th:text が複数あるタグは元のHTMLのエラーとみなす
      raise RuntimeError.new("Syntax Error: #@repr")
    end

    if th_text_attribs.empty?
      @repr
    else
      # タグの最後にth_text_attribs[0].unquoted_value を挿入する
      @repr.sub(/>/, " " + th_text_attribs[0].unquoted_value + ">")
    end
  end
end
```

ここまででも既存のテストに影響はない。(テストに th:text 属性がない為)

```console
$ ruby test_html_parser.rb
Run options: --seed 13992

# Running:

......

Finished in 0.004245s, 1413.4276 runs/s, 4240.2827 assertions/s.

6 runs, 18 assertions, 0 failures, 0 errors, 0 skips
```

HTMLの書き換えに対するテストを追加しよう。

```ruby
  def test_html
    html = <<END
<!--
テスト
-->
<!DOCTYPE html>

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
                        '<div th:text="${obj.property}" ${obj.property}>',
                       )

    ret = @parser.html.parse_to_eof(html.force_encoding('ASCII-8BIT'))
    assert_equal expected.force_encoding('ASCII-8BIT'), HtmlParser.walk(ret)
  end
```

ソース全体: [12th step](https://github.com/jca02266/rparsec_tutorial/tree/step12/)

> RParsec解説
> 繰り返すが、加工処理はパース中ではなくパースが完了した後に呼ばれていることに注意。
> 今回の例では、`to_s` が加工処理であり、これは `HtmlParse.walk()` で呼ばれる。
> いつもこの形を保つこと。

## STEP13: 新しいパーサ

やっと、加工処理の形が整った。あとは、`Attribute#unquoted_value` に対して[SpEL式](https://sites.google.com/site/soracane/home/springnitsuite/spring-no-ji-nengnitsuite/4-spring-expression-langage-spel-shi-xml-dengde-shi-yongdekiruel-shi)のパーサを作成すれば当初の課題を解決することができる。

SpEL式のパーサを真面目に作るのは大変だが、最初の課題に示した自分の問題領域に絞ると以外と簡単にできる。

再掲

```
${obj.property}
${obj.property + "abc"}
${#xxx.function1(obj.property)}
${#xxx.function2("abc", obj.property)}
```

似非BNFで表すとこんな感じか

```
SpEL :: dollar_expression

dollar_expression :: "${" expression "}"

expression :: term op expression
            | term

term :: ident
      | literal
      | function

function :: "#" ident "(" params* ")"
params :: expression "," params
        | expression
ident :: /[A-Za-z][A-Za-z0-9.]/+
literal :: quoted_value | number
quoted_value :: '"' any* '"'
number :: /[0-9]+/
op :: "+" | "-"
```

expressionとかtermとかよく出てくるこういう単語は覚えておくとメソッド名に困らなくて済むし、慣れれば直感的に分かりやすい。
あとは、statement(文)とかprimary(項)とかfactorとか出てくる。term(終端)とprimary,factorの大小関係は自分にはわからない。
(termが循環しているのはルール違反？)

実装は以下である。長いのと特筆すべき点は限られているので一部のみ抜粋する。

```ruby:spel_parser.rb
class SpelParser
  def params
    lazy { seq(expression, space.many, string(","), space.many, params) } |
    expression
  end

  def term
    lazy { ident | literal | function }
  end

  def parse(s)
    (dollar_expression << eof).parse(s)
  end
end
```

> RParsec解説
> `Parsers.lazy { ... }`
> は、ブロックの中のパーサを遅延評価する。
> BNF で
> `params :: expression "," params`
> のように事故参照しているパーサは lazy にする必要があると覚えておけば良い。
> この関数の引数のような再帰定義はお決まりである。
> また、分かりにくいが
>
> ```
> term :: ident
>      | literal
>      | function
> ```
> この定義も term → function → params → expression → term と循環しているため lazy が必要
> lazy を忘れると `SystemStackError: stack level too deep`
> になるので、そのような場合にどこかに循環がないか確認すれば良い。
> なお、term の定義は
>
>  ```
>  def term
>    ident | literal | lazy { function }
>  end
>  ```
>
> でも良い。
>

ここで関数の引数を表す(再帰する)パーサとそれを実現するための `Parsers.lazy()` を解説したので大抵の問題に対応するための道具は揃ったものと思う。

ソース: [13th step](https://github.com/jca02266/rparsec_tutorial/blob/step13/spel_parser.rb)

## STEP14: property を抽出

新しい spel_parser はまだ文字列をパースするだけなので、元の課題である property を取得する処理を追加しよう。
まずは必要なクラス定義。抽出したいのは ident の部分なのでそれを表すIdentクラスとFunctionクラスを定義する。

```ruby:spel_parser.rb
class Function
  def initialize(repr, name, params)
    @repr = repr
    @name = name
    @params = params
  end

  def to_s
    @repr
  end
end

class Ident
  def initialize(repr)
    @repr = @ident = repr
  end

  def to_s
    @repr
  end
end
```

インスタンスを生成する箇所は以下となる。

```ruby:spel_parser.rb
  def function
    sequence(string("#"), ident, string("("), params.optional, string(")")) {|*e|
      Function.new(e.join, e[1], e[3])
    }
  end

  def term
    lazy { ident.map {|e| Ident.new(e)} |
           literal |
           function
         }
  end
```

テストのjoinをto_sに変えるなどは必要だが、それ以外のテストはそのまま通る。

> RParsec解説
> Parsers#map { ... }
> は、パーサの結果をブロックの内容で差し替えるパーサ。
> 今までこの目的に sequence() を使っていたが単独のパーサの結果をオブジェクトにする場合は
> ident.map {|e| Ident.new(e)}
> とすれば良い。
>
> 強いて言えば、今までの例でも
>
> ```
> p sequence(string('a'), string('b'), string('c')) {|*v| v }.parse('abc')
> ```
> ではなく、mapを使って
>
> ```
> p seq(string('a'), string('b'), string('c')).map {|v| v }.parse('abc')
> ```
> のようにしても良かった。(パーサコンビネータの利点を生かして書き換えの量を減らすことが出来た)

ソース全体: [14th step](https://github.com/jca02266/rparsec_tutorial/tree/step14/)

## STEP15: property 抽出

まず、SpelParserクラスのwalk()メソッドでpropertyを集める処理を作る。

```ruby:spel_parser.rb
  def self.walk(parsed_object, property = [])
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
```

```ruby:spel_parser.rb
class Function
  #...

  def property
    case @name
    when 'xxx.function1' then @params.property
    when 'xxx.function2' then @params[4].property
    else
      raise RuntimeError.new("unknown function #{@name}")
    end
  end
end

class Ident
  #...

  def property
    if /\.([^.]+)\z/ =~ @ident
      $1
    end
  end
end
```

そして、HtmlParser で以下のように使えば良い

```ruby:html_parser.rb
class Tag
  #..

  def to_s
    #...

    if th_text_attribs.empty?
      @repr
    else
      # th_text_attribs[0].unquoted_value をパースしてpropertyを抽出する
      ret = SpelParser.new.parse(th_text_attribs[0].unquoted_value)
      properties = []
      SpelParser.walk(ret, properties)

      case properties.size
      when 1
        @repr.sub(/>/, " data-prop='#{properties[0]}'>")
      when 0
        @repr
      else
        raise RuntimeError.new("Too many properties: #{properties.inspect}")
      end
    end
```

ソース全体: [15th step](https://github.com/jca02266/rparsec_tutorial/tree/step15/)

<!-- 私は簡易的なJavaのパーサも作ったりして他の問題解決に活用したこともある。この記事により、パーサが汎用性の高い便利なハンマーになることを示せれば良いと思う。 -->

## STEP16: 改善(params)

一応、ここまでで目的を達成しているのだが、いくつか改善をしようと思う。
今の実装では以下の点が分かりにくい。

```ruby:spel_parser.rb
class Function
  #...
  def property
    case @name
    when 'xxx.function1' then @params.property
    when 'xxx.function2' then @params[4].property
  end
```

`@params`, `@params[4]` というのは以下の params の文法定義から来ている。
`@params` は `|` で区切られた下段、つまり `expression`から、
`@params[4]` は上段、つまり `seq(expression, space.many, string(","), space.many, params)` の`seq`の5番目の引数 `params` を取得している。

```ruby:spel_parser.rb
  def params
    lazy { seq(expression, space.many, string(","), space.many, params) } |
    expression
  end
```

これはなぜかと言うと、`xxx.function1`が引数1つの関数であり、`xxx.function2`が引数2つの関数の2番目の引数が欲しいからなのだが、そのことが分かりにくい。
また、上段の`params`は引数の数によってネストされた配列になる。現在の実装は、これらはjoinされるだけなので再帰的にjoinとto_sで文字列になるので気にする必要はないのだが、例えば3番目の引数が必要な場合にこれでは問題になる。

そこで、`params`を表すクラス`Params`を導入しよう。

```ruby:spel_parser.rb
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
```

このクラス定義自体は大したことはない。`Params.new` の第一引数は元の文字列、第二引数以降は複数の値を保持するための配列になっている。

これを利用した `params` の文法定義は以下のようになる。

```ruby:params変更後
  def params
    lazy {
      seq(expression, space.many, string(","), space.many, params)
    }.map {|e|
      exp, _, _, _, para = e
      Params.new(e.join, exp, *para.params)
    } |
    expression.map {|v| Params.new([*v].join, v) }
  end
```

まず、下段の expression の定義について、mapによってその値は `Params` のインスタンスにしている。この時、`Params.new`の第一引数については説明が必要である。v はその `expression` の定義自体が以下のように右再帰の形を取っている。そのため v は配列か文字列のどちらかになる。

```ruby:spel_parser.rb
  def expression
    lazy { seq(term, space.many, op, space.many, expression) } |
    term
  end
```

そのため、v が配列だった場合は、`[*v]` はその配列のままに、v が文字列だった場合 `[*v]` は`[v]`と同じになる。というRubyの機能を利用している。(そして、joinによりparseした元の文字列を取得している)
`[*v]`はRubyのArray関数を利用して、`Array(v)`としても良いし、冗長に書くなら `case v when String then [v] when Array then v end` でも良い。

次に、上段の定義だが、これもmapによってseqの結果を取得している。seqは常に配列を返すので先ほどとは異なり、`Params.new`の第一引数は `e.join` で良い。そして、第二引数以降は、本来の文法要素だけが必要なので、空白類や","を除いた `exp` (seqの1番目の引数)と `para` (seqの5番目の引数)だけを取得している。

また、`Params.new`には`Params#params`メソッドの結果を使い、`*para.params`とすることで再帰構造を展開している。

```
    }.map {|e|
      exp, _, _, _, para = e
      Params.new(e.join, exp, *para.params)
    }
```

これはややこしいが、この右再帰の構造には常にこの形でParamsクラスによるオブジェクト化ができる。
(先ほど出た expression の定義にも利用できる。そのため、ParamsではなくElementsとかもっと汎用的な名前にしても良かった)
また、そのメソッド名 params がだいぶややこしい。当初 to_a としていたがこれはかなり混乱したので変えたのだが良い名前が思いつかなかった。

`Params`クラスを使っている箇所はもう一つある。

```ruby:spel_parser.rb
  def function
    sequence(string("#"), ident, string("("), params.optional(Params.new('')), string(")")) {|*e|
      _, id, _, para, _ = e
      Function.new(e.join, id, *para.params)
    }
  end
```

> RParsec解説
> `Parser#optional(default=nil)`
> これはパーサselfが省略可能であることを示し、実際に省略された場合はdefaultの値が使われる。つまり、`#function()` のように params に相当する部分が空だった場合も`Params.new('')`によって常に`Params`のインスタンスにしている。
> そうすることで、Function.new をする箇所は
> `Function.new(e.join, id, *para.params)`
> と常に`Params#params`を利用することができる。

ソース全体: [16th step](https://github.com/jca02266/rparsec_tutorial/tree/step16/)
