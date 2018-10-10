# frozen_string_literal: true
module DataCleanup
  module Rules
    # Fix blank user on Answer
    module Answer
      class FixBlankUser < Rules::Base

        def description
          "Fix blank plan on Answer"
        end

        def call
          ::Answer.where.not(plan_id: Plan.all.collect(&:id)).each do |answer|
            unless answer.plan.present?
              log("Destroying orphaned Answer##{answer.id}")
              answer.destroy
            end
          end
        end

      end
    end

  end
end