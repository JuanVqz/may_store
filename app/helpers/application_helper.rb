module ApplicationHelper
  # Disponible en todas las vistas, incluyendo las de Rails::PwaController
  # que NO hereda de nuestro ApplicationController.
  def current_store
    Current.store || Store.find_by(subdomain: request.subdomain)
  end

  def order_status_border_class(status)
    case status.to_s
    when "open" then "border-amber-300"
    when "cooking" then "border-orange-500"
    when "ready" then "border-green-500"
    when "delivered" then "border-purple-500"
    when "closed" then "border-muted-foreground"
    when "cancelled" then "border-destructive"
    else "border-border"
    end
  end

  def status_badge_classes(status)
    base = "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold"
    color = case status.to_s
    when "open", "ordering" then "bg-amber-100 text-amber-800"
    when "cooking" then "bg-orange-100 text-orange-800"
    when "ready" then "bg-green-100 text-green-800"
    when "delivered" then "bg-purple-100 text-purple-800"
    when "closed" then "bg-muted text-muted-foreground"
    when "cancelled" then "bg-red-100 text-red-800"
    else "bg-muted text-muted-foreground"
    end
    "#{base} #{color}"
  end
end
