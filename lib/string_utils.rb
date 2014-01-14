module StringUtils
  ALPHANUMERICS=[('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten

  def self.generate_alphanumeric(length)
    (0...length).map { ALPHANUMERICS[rand(ALPHANUMERICS.length)] }.join
  end
end
