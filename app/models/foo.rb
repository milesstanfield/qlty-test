class Foo < ApplicationRecord
  def env_local_example
    Rails.env.development? || Rails.env.test?
  end
end
