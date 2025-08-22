module Spina
  class ReplaceSignedIdJob < ApplicationJob
    queue_as { Spina.config.queues[:page_updates] }

    def perform(old_signed_id, new_signed_id)
      return if old_signed_id.blank? || new_signed_id.blank?

      pages = get_pages(old_signed_id)
      accounts = Spina::Account.all

      [pages, accounts].each do |records|
        records.update_all("json_attributes = REPLACE(json_attributes, '#{old_signed_id}', '#{new_signed_id}')")
      end
    end

    private

    def get_pages(signed_id)
      return Spina::Page.none unless signed_id.present?
      Spina::Page.where("json_attributes LIKE ?", "%#{signed_id}%")
    end
  end
end
