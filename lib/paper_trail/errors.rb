module PaperTrail
  # A base error class for PaperTrail.
  class Error < StandardError
  end

  class UnsupportedModel < Error
  end
end
