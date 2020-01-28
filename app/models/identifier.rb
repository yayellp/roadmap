# frozen_string_literal: true

# == Schema Information
#
# Table name: identifiers
#
#  id                   :integer          not null, primary key
#  attrs                :string
#  value                :string           not null
#  created_at           :datetime
#  updated_at           :datetime
#  identifier_scheme_id :integer          not null
#  identifiable_id      :integer          not null
#  identifiable_type    :string           not null
#
# Foreign Keys
#
#  fk_rails_...  (identifier_scheme_id => identifier_schemes.id)
#
class Identifier < ActiveRecord::Base

  include ValidationMessages

  # ================
  # = Associations =
  # ================

  belongs_to :identifiable, polymorphic: true

  belongs_to :identifier_scheme

  # ===============
  # = Validations =
  # ===============

  validates :identifier_scheme,
            presence: { message: PRESENCE_MESSAGE },
            uniqueness: { scope: %i[identifiable_id identifiable_type],
                          message: UNIQUENESS_MESSAGE }

  validates :value, presence: { message: PRESENCE_MESSAGE }

  validates :identifiable, presence: { message: PRESENCE_MESSAGE }

  # ===============
  # = Scopes =
  # ===============

  def self.by_scheme_name(value, identifiable_type)
    where(identifier_scheme: IdentifierScheme.by_name(value),
          identifiable_type: identifiable_type)
  end

  # ===========================
  # = Public instance methods =
  # ===========================

  def attrs=(hash)
    write_attribute(:attrs, (hash.is_a?(Hash) ? hash.to_json.to_s : "{}"))
  end

end
