# encoding: UTF-8

require File.join(File.dirname(__FILE__),"levenshtein/version.rb")

module Levenshtein
  # Returns the Levenshtein distance as a number between 0.0 and
  # 1.0. It's basically the Levenshtein distance divided by the
  # size of the longest sequence.

  def self.normalized_distance(a1, a2, threshold=nil, options={})
    size	= [a1.size, a2.size].max

    if a1.size == 0 and a2.size == 0
      0.0
    elsif a1.size == 0
      a2.size.to_f/size
    elsif a2.size == 0
      a1.size.to_f/size
    else
      if threshold
        if d = self.distance(a1, a2, (threshold*size).to_i+1)
          d.to_f/size
        else
          nil
        end
      else
        self.distance(a1, a2).to_f/size
      end
    end
  end

  # Returns the Levenshtein distance between two sequences.
  #
  # The two sequences can be two strings, two arrays, or two other
  # objects responding to :each. All sequences are by generic
  # (fast) C code.
  #
  # All objects in the sequences should respond to :hash and :eql?.

  def self.distance(a1, a2, threshold=nil, options={})
    a1, a2	= a1.scan(/./), a2.scan(/./)	if String === a1 and String === a2
    a1, a2	= Util.pool(a1, a2)

    # Handle some basic circumstances.

    return 0		if a1 == a2
    return a2.size	if a1.empty?
    return a1.size	if a2.empty?

    if threshold
      return nil	if (a1.size-a2.size) >= threshold
      return nil	if (a2.size-a1.size) >= threshold
      return nil	if (a1-a2).size >= threshold
      return nil	if (a2-a1).size >= threshold
    end

    # Remove the common prefix and the common postfix.

    l1	= a1.size
    l2	= a2.size

    offset			= 0
    no_more_optimizations	= true

    while offset < l1 and offset < l2 and a1[offset].equal?(a2[offset])
      offset += 1

      no_more_optimizations	= false
    end

    while offset < l1 and offset < l2 and a1[l1-1].equal?(a2[l2-1])
      l1 -= 1
      l2 -= 1

      no_more_optimizations	= false
    end

    if no_more_optimizations
      distance_fast_or_slow(a1, a2, threshold, options)
    else
      l1 -= offset
      l2 -= offset

      a1	= a1[offset, l1]
      a2	= a2[offset, l2]

      distance(a1, a2, threshold, options)
    end
  end

  def self.distance_fast_or_slow(a1, a2, threshold, options)	# :nodoc:
    if respond_to?(:distance_fast) and options[:force_slow]
      distance_fast(a1, a2, threshold)	# Implemented in C.
    else
      distance_slow(a1, a2, threshold)	# Implemented in Ruby.
    end
  end

  def self.distance_slow(a1, a2, threshold)	# :nodoc:
    crow	= (0..a1.size).to_a

    1.upto(a2.size) do |y|
      prow	= crow
      crow	= [y]

      1.upto(a1.size) do |x|
        crow[x]	= [prow[x]+1, crow[x-1]+1, prow[x-1]+(a1[x-1].equal?(a2[y-1]) ? 0 : 1)].min
      end

      # Stop analysing this sequence as soon as the best possible
      # result for this sequence is bigger than the best result so far.
      # (The minimum value in the next row will be equal to or greater
      # than the minimum value in this row.)

      return nil	if threshold and crow.min >= threshold
    end

    crow[-1]
  end

  module Util	# :nodoc:
    def self.pool(*args)
      # So we can compare pointers instead of objects (equal?() instead of ==()).

      pool	= {}

      args.collect do |arg|
        a	= []

        arg.each do |o|
          a << pool[o] ||= o
        end

        a
      end
    end
  end
end

# begin
#   require File.join(File.dirname(__FILE__),"levenshtein/levenshtein_fast")	# Compiled by RubyGems.
# rescue LoadError
#   begin
#     require "levenshtein_fast"			# Compiled by the build script.
#   rescue LoadError
#     $stderr.puts "WARNING: Couldn't find the fast C implementation of Levenshtein. Using the much slower Ruby version instead."
#   end
# end
