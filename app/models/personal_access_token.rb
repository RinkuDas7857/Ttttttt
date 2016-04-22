class PersonalAccessToken < ActiveRecord::Base
  belongs_to :user

  scope :active, -> { where(revoked: false).where("expires_at >= NOW() OR expires_at IS NULL") }
  scope :inactive, -> { where("revoked = true OR expires_at < NOW()") }

  def self.generate(params)
    personal_access_token = self.new(params)
    personal_access_token.token = Devise.friendly_token(50)
    personal_access_token
  end

  def revoke!
    self.revoked = true
    self.save
  end
end
