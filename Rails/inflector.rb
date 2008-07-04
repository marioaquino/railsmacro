# Copyright (c) 2004 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#!/usr/bin/ruby
require 'singleton'
require 'enumerator'

# The Inflector transforms words from singular to plural, class names to table names, modularized class names to ones without,
# and class names to foreign keys. The default inflections for pluralization, singularization, and uncountable words are kept
# in inflections.rb.
module Inflector 
  # A singleton instance of this class is yielded by Inflector.inflections, which can then be used to specify additional
  # inflection rules. Examples:
  #
  #   Inflector.inflections do |inflect|
  #     inflect.plural /^(ox)$/i, '\1\2en'
  #     inflect.singular /^(ox)en/i, '\1'
  #
  #     inflect.irregular 'octopus', 'octopi'
  #
  #     inflect.uncountable "equipment"
  #   end
  #
  # New rules are added at the top. So in the example above, the irregular rule for octopus will now be the first of the
  # pluralization and singularization rules that is runs. This guarantees that your rules run before any of the rules that may
  # already have been loaded.
  class Inflections
    include Singleton
    
    attr_reader :plurals, :singulars, :uncountables
    
    def initialize
      @plurals, @singulars, @uncountables = [], [], []
    end
    
    # Specifies a new pluralization rule and its replacement. The rule can either be a string or a regular expression. 
    # The replacement should always be a string that may include references to the matched data from the rule.
    def plural(rule, replacement)
      @plurals.insert(0, [rule, replacement])
    end
    
    # Specifies a new singularization rule and its replacement. The rule can either be a string or a regular expression. 
    # The replacement should always be a string that may include references to the matched data from the rule.
    def singular(rule, replacement)
      @singulars.insert(0, [rule, replacement])
    end

    # Specifies a new irregular that applies to both pluralization and singularization at the same time. This can only be used
    # for strings, not regular expressions. You simply pass the irregular in singular and plural form.
    # 
    # Examples:
    #   irregular 'octopus', 'octopi'
    #   irregular 'person', 'people'
    def irregular(singular, plural)
      plural(Regexp.new("(#{singular[0,1]})#{singular[1..-1]}$", "i"), '\1' + plural[1..-1])
      singular(Regexp.new("(#{plural[0,1]})#{plural[1..-1]}$", "i"), '\1' + singular[1..-1])
    end
    
    # Add uncountable words that shouldn't be attempted inflected.
    # 
    # Examples:
    #   uncountable "money"
    #   uncountable "money", "information"
    #   uncountable %w( money information rice )
    def uncountable(*words)
      (@uncountables << words).flatten!
    end
    
    # Clears the loaded inflections within a given scope (default is :all). Give the scope as a symbol of the inflection type,
    # the options are: :plurals, :singulars, :uncountables
    #
    # Examples:
    #   clear :all
    #   clear :plurals
    def clear(scope = :all)
      case scope
        when :all
          @plurals, @singulars, @uncountables = [], [], []
        else
          instance_variable_set "@#{scope}", []
      end
    end
  end

  extend self

  def inflections
    if block_given?
      yield Inflections.instance
    else
      Inflections.instance
    end
  end

  def pluralize(word)
    result = word.to_s.dup

    if inflections.uncountables.include?(result.downcase)
      result
    else
      inflections.plurals.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
      result
    end
  end

  def singularize(word)
    result = word.to_s.dup

    if inflections.uncountables.include?(result.downcase)
      result
    else
      inflections.singulars.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
      result
    end
  end

  def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
    if first_letter_in_uppercase
      lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
    else
      lower_case_and_underscored_word.first + camelize(lower_case_and_underscored_word)[1..-1]
    end
  end

  def titleize(word)
    humanize(underscore(word)).gsub(/\b([a-z])/) { $1.capitalize }
  end
  
  def underscore(camel_cased_word)
    camel_cased_word.to_s.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
  end
  
  def dasherize(underscored_word)
    underscored_word.gsub(/_/, '-')
  end

  def humanize(lower_case_and_underscored_word)
    lower_case_and_underscored_word.to_s.gsub(/_id$/, "").gsub(/_/, " ").capitalize
  end

  def demodulize(class_name_in_module)
    class_name_in_module.to_s.gsub(/^.*::/, '')
  end

  def tableize(class_name)
    pluralize(underscore(class_name))
  end
  
  def classify(table_name)
    camelize(singularize(table_name))
  end

  def foreign_key(class_name, separate_class_name_and_id_with_underscore = true)
    underscore(demodulize(class_name)) + (separate_class_name_and_id_with_underscore ? "_id" : "id")
  end

  def constantize(camel_cased_word)
    raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!" unless
      /^(::)?([A-Z]\w*)(::[A-Z]\w*)*$/ =~ camel_cased_word
    
    camel_cased_word = "::#{camel_cased_word}" unless $1
    Object.module_eval(camel_cased_word, __FILE__, __LINE__)
  end

  def ordinalize(number)
    if (11..13).include?(number.to_i % 100)
      "#{number}th"
    else
      case number.to_i % 10
        when 1: "#{number}st"
        when 2: "#{number}nd"
        when 3: "#{number}rd"
        else    "#{number}th"
      end
    end
  end
end

Inflector.inflections do |inflect|
  inflect.plural(/$/, 's')
  inflect.plural(/s$/i, 's')
  inflect.plural(/(ax|test)is$/i, '\1es')
  inflect.plural(/(octop|vir)us$/i, '\1i')
  inflect.plural(/(alias|status)$/i, '\1es')
  inflect.plural(/(bu)s$/i, '\1ses')
  inflect.plural(/(buffal|tomat)o$/i, '\1oes')
  inflect.plural(/([ti])um$/i, '\1a')
  inflect.plural(/sis$/i, 'ses')
  inflect.plural(/(?:([^f])fe|([lr])f)$/i, '\1\2ves')
  inflect.plural(/(hive)$/i, '\1s')
  inflect.plural(/([^aeiouy]|qu)y$/i, '\1ies')
  inflect.plural(/([^aeiouy]|qu)ies$/i, '\1y')
  inflect.plural(/(x|ch|ss|sh)$/i, '\1es')
  inflect.plural(/(matr|vert|ind)ix|ex$/i, '\1ices')
  inflect.plural(/([m|l])ouse$/i, '\1ice')
  inflect.plural(/^(ox)$/i, '\1en')
  inflect.plural(/(quiz)$/i, '\1zes')

  inflect.singular(/s$/i, '')
  inflect.singular(/(n)ews$/i, '\1ews')
  inflect.singular(/([ti])a$/i, '\1um')
  inflect.singular(/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)ses$/i, '\1\2sis')
  inflect.singular(/(^analy)ses$/i, '\1sis')
  inflect.singular(/([^f])ves$/i, '\1fe')
  inflect.singular(/(hive)s$/i, '\1')
  inflect.singular(/(tive)s$/i, '\1')
  inflect.singular(/([lr])ves$/i, '\1f')
  inflect.singular(/([^aeiouy]|qu)ies$/i, '\1y')
  inflect.singular(/(s)eries$/i, '\1eries')
  inflect.singular(/(m)ovies$/i, '\1ovie')
  inflect.singular(/(x|ch|ss|sh)es$/i, '\1')
  inflect.singular(/([m|l])ice$/i, '\1ouse')
  inflect.singular(/(bus)es$/i, '\1')
  inflect.singular(/(o)es$/i, '\1')
  inflect.singular(/(shoe)s$/i, '\1')
  inflect.singular(/(cris|ax|test)es$/i, '\1is')
  inflect.singular(/([octop|vir])i$/i, '\1us')
  inflect.singular(/(alias|status)es$/i, '\1')
  inflect.singular(/^(ox)en/i, '\1')
  inflect.singular(/(vert|ind)ices$/i, '\1ex')
  inflect.singular(/(matr)ices$/i, '\1ix')
  inflect.singular(/(quiz)zes$/i, '\1')

  inflect.irregular('person', 'people')
  inflect.irregular('man', 'men')
  inflect.irregular('child', 'children')
  inflect.irregular('sex', 'sexes')
  inflect.irregular('move', 'moves')

  inflect.uncountable(%w(equipment information rice money species series fish sheep))
end

class Foo
  include Inflector
end

foo = Foo.new
ARGV.each_slice(2) {|arr| puts foo.send(arr[0].to_sym, arr[1]) }
