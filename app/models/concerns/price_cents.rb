module PriceCents
  extend ActiveSupport::Concern

  class_methods do
    def price_in_cents(*attributes)
      attributes.each do |attr|
        cents_attr = "#{attr}_cents"

        define_method(attr) do
          send(cents_attr) / 100.0
        end

        define_method("#{attr}=") do |dollars|
          send("#{cents_attr}=", (dollars.to_f * 100).round)
        end

        define_method("formatted_#{attr}") do
          "$#{'%.2f' % send(attr)}"
        end
      end
    end
  end
end
