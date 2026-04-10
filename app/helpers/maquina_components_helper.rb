# frozen_string_literal: true

module MaquinaComponentsHelper
  include MaquinaComponents::SidebarHelper
  include MaquinaComponents::IconsHelper
  include MaquinaComponents::ToastHelper

  def main_icon_svg_for(name)
    nil
  end

  def app_sidebar_state(cookie_name = "sidebar_state")
    sidebar_state(cookie_name)
  end

  def app_sidebar_open?(cookie_name = "sidebar_state")
    sidebar_open?(cookie_name)
  end

  def app_sidebar_closed?(cookie_name = "sidebar_state")
    sidebar_closed?(cookie_name)
  end
end
