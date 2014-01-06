class ApplicationController < ActionController::Base
  require 'awesome_print'
  protect_from_forgery
  $debug_msg = ''
  $debug_hash = {}

  def log key, value, indent = 4
    indent.times { print ' '}
    print '    ' + key + ': '
    ap value, :indent => 8 + indent, :color => {
      :args       => :red,   # purpleish
      :array      => :white,
      :bigdecimal => :blue,
      :class      => :yellow,
      :date       => :blueish,
      :falseclass => :red,
      :fixnum     => :blue,
      :float      => :blue,
      :hash       => :gray,  # redish
      :keyword    => :cyan,  # cyanish
      :method     => :purpleish,
      :nilclass   => :red,
      :rational   => :blue,
      :string     => :yellowish,
      :struct     => :pale,
      :symbol     => :cyanish,
      :time       => :blue,
      :trueclass  => :green,
      :variable   => :cyanish
    }
  end
end
