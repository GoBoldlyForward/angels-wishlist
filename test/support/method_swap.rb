# frozen_string_literal: true

# Replaces a singleton method for the length of a block, which is how these
# tests stand in for Stripe without a mocking library.
module MethodSwap
  def swapping(object, name, replacement)
    original = object.method(name)
    object.define_singleton_method(name, &replacement)
    yield
  ensure
    object.define_singleton_method(name, original)
  end
end
