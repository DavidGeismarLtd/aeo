# frozen_string_literal: true

# User model for authentication and authorization
# Uses Devise for authentication with email confirmation
class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  # Associations
  has_many :workspace_memberships, dependent: :destroy
  has_many :workspaces, through: :workspace_memberships

  # Validations
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Callbacks
  before_save :downcase_email

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def initials
    "#{first_name[0]}#{last_name[0]}".upcase
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end
end
